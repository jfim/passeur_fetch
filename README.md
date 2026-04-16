# Passeur Fetch

MCP tool for [Passeur](https://github.com/jfim/passeur) that fetches web pages and extracts readable content as markdown. Uses [Readability](https://github.com/keepcosmos/readability) for article extraction and [Htmd](https://github.com/kasvith/htmd) for HTML-to-markdown conversion.

## Tools

| Tool | Description |
|------|-------------|
| `fetch_url` | Fetch a URL and return its readable content as markdown |

### Parameters

- `url` (required) — URL to fetch (http or https)
- `content_token_limit` (optional) — Maximum estimated tokens to return (~4 chars per token)

## Usage

Add to your MCP server project:

```elixir
# mix.exs
{:passeur_fetch, path: "../passeur_fetch"}
```

Register the tool in your MCP server:

```elixir
defmodule MyServer.MCPServer do
  use Anubis.Server,
    name: "MyServer",
    version: "0.1.0",
    capabilities: [:tools]

  component PasseurFetch.Tools.FetchUrl

  @impl true
  def init(_client_info, frame), do: {:ok, frame}
end
```

## License

MIT
