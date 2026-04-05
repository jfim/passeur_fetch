defmodule PasseurFetch.Tools.FetchUrl do
  @moduledoc "Fetch a URL and extract readable content"

  use Hermes.Server.Component, type: :tool

  @chars_per_token 4

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

  defp fetch(url) do
    request = Finch.build(:get, url)

    case Finch.request(request, PasseurFetch.Finch) do
      {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Finch.Response{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
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
