defmodule PasseurFetch.Tools.FetchUrl do
  @moduledoc "Fetch a URL and extract readable content"

  use Anubis.Server.Component, type: :tool
  require Logger

  @chars_per_token 4
  @max_redirects 5
  @request_timeout_ms 15_000
  # Time we let passe-partout's network-idle wait run before giving up. Sized to
  # the long-tail of slow JS-heavy pages; bounded so we still fit inside
  # @overall_timeout_ms with room for create_tab + html fetch + tab cleanup.
  @network_idle_timeout_ms 30_000
  # Finch budget for the /wait call specifically — must exceed
  # @network_idle_timeout_ms (passe-partout returns 200 even when its own wait
  # timed out, but only after that wait has finished).
  @wait_request_timeout_ms 35_000
  @overall_timeout_ms 75_000
  @max_body_bytes 5_000_000
  @user_agent "PasseurFetch/0.1"

  schema do
    field(:url, {:required, :string}, description: "URL to fetch (http or https)")

    field(:content_token_limit, :integer,
      description: "Maximum estimated tokens to return (approx 4 chars per token)"
    )
  end

  @impl true
  def execute(%{url: url} = params, frame) do
    content_token_limit = Map.get(params, :content_token_limit)
    Logger.info("Fetching #{url}")

    task = Task.async(fn -> do_fetch(url, content_token_limit) end)

    case Task.yield(task, @overall_timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, text}} ->
        Logger.info("Successfully fetched #{url} (#{String.length(text)} chars)")

        {:reply,
         Anubis.Server.Response.tool()
         |> Anubis.Server.Response.text(text), frame}

      {:ok, {:error, reason}} ->
        Logger.warning("Failed to fetch #{url}: #{reason}")

        {:reply,
         Anubis.Server.Response.tool()
         |> Anubis.Server.Response.text("Error: #{reason}"), frame}

      nil ->
        Logger.error("Timed out fetching #{url} after #{@overall_timeout_ms}ms")

        {:reply,
         Anubis.Server.Response.tool()
         |> Anubis.Server.Response.text(
           "Error: Operation timed out after #{@overall_timeout_ms}ms"
         ), frame}
    end
  end

  defp do_fetch(url, content_token_limit) do
    with :ok <- validate_url(url),
         {:ok, body, content_type} <- fetch_with_fallback(url),
         {:ok, text} <- extract_text(body, content_type) do
      {:ok, maybe_truncate(text, content_token_limit)}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp fetch_with_fallback(url) do
    case fetch(url) do
      {:error, {:http_4xx, status}} ->
        case PasseurFetch.Config.passe_partout_host() do
          nil ->
            {:error, "HTTP #{status}"}

          host ->
            Logger.info("HTTP #{status} from #{url}, falling back to passe-partout")
            fetch_via_passe_partout(host, url)
        end

      other ->
        other
    end
  end

  defp fetch_via_passe_partout(host, url) do
    base = String.trim_trailing(host, "/")

    case create_tab(base, url) do
      {:ok, tab_id, content_type} ->
        # Wait for network idle so SPA / JS-rendered content is in the DOM
        # before we read it. Best-effort: failures (including the wait timing
        # out inside passe-partout) are non-fatal — we still try to read.
        _ = wait_for_network_idle(base, tab_id)

        result =
          cond do
            html_content_type?(content_type) ->
              get_tab_html(base, tab_id)

            text_content_type?(content_type) ->
              get_tab_text(base, tab_id)

            true ->
              {:error,
               "passe-partout returned unsupported content-type: #{content_type || "unknown"}"}
          end

        delete_tab(base, tab_id)

        case result do
          {:ok, body} ->
            with :ok <- validate_body_size(body), do: {:ok, body, content_type}

          {:error, _} = err ->
            err
        end

      {:error, _} = err ->
        err
    end
  end

  defp passe_partout_headers do
    [{"content-type", "application/json"}, {"user-agent", @user_agent}] ++
      case PasseurFetch.Config.passe_partout_bearer_token() do
        nil -> []
        token -> [{"authorization", "Bearer " <> token}]
      end
  end

  defp create_tab(base, url) do
    body = Jason.encode!(%{url: url})
    request = Finch.build(:post, base <> "/tabs", passe_partout_headers(), body)

    case Finch.request(request, PasseurFetch.Finch, receive_timeout: @request_timeout_ms) do
      {:ok, %Finch.Response{status: status, body: resp_body}} when status in 200..299 ->
        case Jason.decode(resp_body) do
          {:ok, %{"id" => id, "status" => upstream_status} = body_json}
          when is_integer(id) and upstream_status in 200..299 ->
            {:ok, id, Map.get(body_json, "content_type")}

          {:ok, %{"id" => id, "status" => upstream_status}} when is_integer(id) ->
            delete_tab(base, id)
            {:error, "passe-partout upstream returned HTTP #{upstream_status}"}

          {:ok, _} ->
            {:error, "passe-partout response missing id"}

          {:error, _} ->
            {:error, "passe-partout returned invalid JSON"}
        end

      {:ok, %Finch.Response{status: status}} ->
        {:error, "passe-partout returned HTTP #{status}"}

      {:error, reason} ->
        {:error, "passe-partout request failed: #{inspect(reason)}"}
    end
  end

  defp wait_for_network_idle(base, tab_id) do
    body = Jason.encode!(%{network_idle: true, timeout_ms: @network_idle_timeout_ms})
    request = Finch.build(:post, base <> "/tabs/#{tab_id}/wait", passe_partout_headers(), body)

    case Finch.request(request, PasseurFetch.Finch, receive_timeout: @wait_request_timeout_ms) do
      {:ok, %Finch.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Finch.Response{status: status}} ->
        Logger.debug("passe-partout /wait returned HTTP #{status} for tab #{tab_id}")
        :ok

      {:error, reason} ->
        Logger.debug("passe-partout /wait request failed for tab #{tab_id}: #{inspect(reason)}")
        :ok
    end
  end

  defp get_tab_html(base, tab_id) do
    request = Finch.build(:get, base <> "/tabs/#{tab_id}/html", passe_partout_headers())

    case Finch.request(request, PasseurFetch.Finch, receive_timeout: @request_timeout_ms) do
      {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Finch.Response{status: status}} ->
        {:error, "passe-partout /html returned HTTP #{status}"}

      {:error, reason} ->
        {:error, "passe-partout /html request failed: #{inspect(reason)}"}
    end
  end

  defp get_tab_text(base, tab_id) do
    body = Jason.encode!(%{js: "document.body.innerText"})
    request = Finch.build(:post, base <> "/tabs/#{tab_id}/eval", passe_partout_headers(), body)

    case Finch.request(request, PasseurFetch.Finch, receive_timeout: @request_timeout_ms) do
      {:ok, %Finch.Response{status: status, body: resp_body}} when status in 200..299 ->
        case Jason.decode(resp_body) do
          {:ok, %{"result" => result}} when is_binary(result) ->
            {:ok, result}

          {:ok, %{"result" => result}} ->
            {:ok, to_string(result)}

          _ ->
            {:error, "passe-partout /eval returned unexpected body"}
        end

      {:ok, %Finch.Response{status: status}} ->
        {:error, "passe-partout /eval returned HTTP #{status}"}

      {:error, reason} ->
        {:error, "passe-partout /eval request failed: #{inspect(reason)}"}
    end
  end

  defp delete_tab(base, tab_id) do
    request = Finch.build(:delete, base <> "/tabs/#{tab_id}", passe_partout_headers())

    case Finch.request(request, PasseurFetch.Finch, receive_timeout: @request_timeout_ms) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to delete passe-partout tab #{tab_id}: #{inspect(reason)}")
        :ok
    end
  end

  defp validate_url(url) do
    uri = URI.parse(url)

    if uri.scheme in ["http", "https"] and uri.host not in [nil, ""] do
      :ok
    else
      {:error, "Invalid URL: must start with http:// or https://"}
    end
  end

  defp fetch(url), do: fetch(url, @max_redirects)

  defp fetch(_url, 0), do: {:error, "Too many redirects"}

  defp fetch(url, redirects_remaining) do
    request = Finch.build(:get, url, [{"user-agent", @user_agent}])

    case Finch.request(request, PasseurFetch.Finch, receive_timeout: @request_timeout_ms) do
      {:ok, %Finch.Response{status: status, headers: headers, body: body}}
      when status in 200..299 ->
        Logger.debug("HTTP #{status} from #{url} (#{byte_size(body)} bytes)")
        content_type = get_content_type(headers)

        with :ok <- validate_supported_content_type(content_type),
             :ok <- validate_body_size(body) do
          {:ok, body, content_type}
        end

      {:ok, %Finch.Response{status: status, headers: headers}}
      when status in [301, 302, 303, 307, 308] ->
        case List.keyfind(headers, "location", 0) do
          {_, location} ->
            resolved = resolve_url(url, location)
            Logger.debug("Redirected #{status} from #{url} to #{resolved}")
            fetch(resolved, redirects_remaining - 1)

          nil ->
            {:error, "HTTP #{status} with no location header"}
        end

      {:ok, %Finch.Response{status: status}} when status in 400..499 ->
        {:error, {:http_4xx, status}}

      {:ok, %Finch.Response{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, %Mint.TransportError{reason: :timeout}} ->
        {:error, "Request timed out"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp resolve_url(base_url, location) do
    uri = URI.parse(location)

    if uri.scheme do
      location
    else
      base = URI.parse(base_url)
      URI.to_string(%{base | path: uri.path, query: uri.query, fragment: uri.fragment})
    end
  end

  defp get_content_type(headers) do
    case List.keyfind(headers, "content-type", 0) do
      {_, content_type} -> content_type
      nil -> nil
    end
  end

  defp validate_supported_content_type(nil), do: :ok

  defp validate_supported_content_type(content_type) do
    if html_content_type?(content_type) or text_content_type?(content_type) do
      :ok
    else
      {:error, "Unsupported content-type: #{content_type}"}
    end
  end

  defp html_content_type?(nil), do: false
  defp html_content_type?(ct), do: String.contains?(ct, "html")

  defp text_content_type?(nil), do: false

  defp text_content_type?(ct) do
    ct = String.downcase(ct)

    String.starts_with?(ct, "text/") or String.contains?(ct, "json") or
      String.contains?(ct, "xml") or String.contains?(ct, "javascript") or
      String.contains?(ct, "yaml")
  end

  defp validate_body_size(body) do
    if byte_size(body) <= @max_body_bytes do
      :ok
    else
      {:error, "Response too large (#{byte_size(body)} bytes, max #{@max_body_bytes})"}
    end
  end

  defp extract_text(body, content_type) do
    cond do
      html_content_type?(content_type) ->
        extract_html(body)

      text_content_type?(content_type) ->
        {:ok, body}

      content_type == nil ->
        # No content-type header — try HTML extraction, but if it yields nothing usable,
        # fall back to returning the raw body so we don't drop plain-text payloads.
        case extract_html(body) do
          {:ok, text} -> {:ok, text}
          {:error, _} -> {:ok, body}
        end

      true ->
        {:error, "Unsupported content-type: #{content_type}"}
    end
  end

  defp extract_html(html) do
    case html |> Readability.article() |> Readability.readable_html() do
      article_html when is_binary(article_html) and article_html != "" ->
        Htmd.convert(article_html)

      _ ->
        {:error, "Could not extract readable content"}
    end
  end

  defp maybe_truncate(text, nil), do: text

  defp maybe_truncate(text, token_limit) do
    char_limit = token_limit * @chars_per_token

    if String.length(text) > char_limit do
      String.slice(text, 0, char_limit)
    else
      text
    end
  end
end
