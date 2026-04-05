defmodule PasseurFetch.Tools.FetchUrl do
  @moduledoc "Fetch a URL and extract readable content"

  use Hermes.Server.Component, type: :tool

  @chars_per_token 4
  @max_redirects 5
  @request_timeout_ms 30_000
  @max_body_bytes 5_000_000
  @user_agent "PasseurFetch/0.1"

  schema do
    field :url, {:required, :string}, description: "URL to fetch (http or https)"

    field :content_token_limit, :integer,
      description: "Maximum estimated tokens to return (approx 4 chars per token)"
  end

  @impl true
  def execute(%{url: url} = params, frame) do
    content_token_limit = Map.get(params, :content_token_limit)

    with :ok <- validate_url(url),
         {:ok, html} <- fetch(url),
         {:ok, text} <- extract_text(html) do
      text = maybe_truncate(text, content_token_limit)

      {:reply,
       Hermes.Server.Response.tool()
       |> Hermes.Server.Response.text(text), frame}
    else
      {:error, reason} ->
        {:reply,
         Hermes.Server.Response.tool()
         |> Hermes.Server.Response.text("Error: #{reason}"), frame}
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
      {:ok, %Finch.Response{status: status, headers: headers, body: body}} when status in 200..299 ->
        with :ok <- validate_content_type(headers),
             :ok <- validate_body_size(body) do
          {:ok, body}
        end

      {:ok, %Finch.Response{status: status, headers: headers}} when status in [301, 302, 303, 307, 308] ->
        case List.keyfind(headers, "location", 0) do
          {_, location} -> fetch(location, redirects_remaining - 1)
          nil -> {:error, "HTTP #{status} with no location header"}
        end

      {:ok, %Finch.Response{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, %Mint.TransportError{reason: :timeout}} ->
        {:error, "Request timed out"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp validate_content_type(headers) do
    case List.keyfind(headers, "content-type", 0) do
      {_, content_type} ->
        if String.contains?(content_type, "html") do
          :ok
        else
          {:error, "Expected HTML content, got: #{content_type}"}
        end

      nil ->
        # No content-type header, try to parse anyway
        :ok
    end
  end

  defp validate_body_size(body) do
    if byte_size(body) <= @max_body_bytes do
      :ok
    else
      {:error, "Response too large (#{byte_size(body)} bytes, max #{@max_body_bytes})"}
    end
  end

  defp extract_text(html) do
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
