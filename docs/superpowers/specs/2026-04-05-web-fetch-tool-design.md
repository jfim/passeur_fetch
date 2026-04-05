# Web Fetch MCP Tool Design

## Overview

Add a web fetch MCP tool to the `passeur_fetch` project that fetches a URL, extracts readable content using the `readability` Elixir library, and returns the text. Replace existing `passeur_files` code entirely.

## Parameters

- `url` (required, string) — URL to fetch. Must start with `http://` or `https://`.
- `content_token_limit` (optional, integer) — Maximum estimated tokens to return. Estimated at ~4 characters per token. When exceeded, the readable text is truncated to fit.

## Architecture

### Namespace

- New top-level module: `PasseurFetch`
- Tool module: `PasseurFetch.Tools.FetchUrl`
- Application module: `PasseurFetch.Application` (supervises Finch pool)

### Removal

All `PasseurFiles` modules and files are removed:
- `lib/passeur_files/` directory (including all tools)
- `lib/passeur_files.ex`
- `test/passeur_files_test.exs`

### Flow

1. Validate URL starts with `http://` or `https://`
2. HTTP GET the URL using Finch (named pool `PasseurFetch.Finch`)
3. Pass HTML response body through `Readability` to extract article content
4. Estimate token count as `String.length(text) / 4`
5. If `content_token_limit` is set and exceeded, truncate text to `content_token_limit * 4` characters
6. Return readable text via `Hermes.Server.Response`

### Dependencies

**Add:**
- `readability` — HTML content extraction

**Keep:**
- `hermes_mcp ~> 0.14.1`
- `jason ~> 1.4`

**Finch** is already a transitive dependency via hermes_mcp.

### Finch Pool

A named Finch instance (`PasseurFetch.Finch`) started in the application supervision tree via `PasseurFetch.Application`.

### Error Handling

- Invalid URL (missing http/https scheme) → error response with message
- Non-2xx HTTP status → error response with status code
- Readability parse failure → error response

### Registration

Registered in the host MCP server config:
```elixir
component PasseurFetch.Tools.FetchUrl
```

## Files

| Action | Path |
|--------|------|
| Delete | `lib/passeur_files.ex` |
| Delete | `lib/passeur_files/tools/delete_file.ex` |
| Delete | `lib/passeur_files/tools/edit_file.ex` |
| Delete | `lib/passeur_files/tools/list_files.ex` |
| Delete | `lib/passeur_files/tools/read_file.ex` |
| Delete | `lib/passeur_files/tools/write_file.ex` |
| Delete | `test/passeur_files_test.exs` |
| Create | `lib/passeur_fetch.ex` |
| Create | `lib/passeur_fetch/application.ex` |
| Create | `lib/passeur_fetch/tools/fetch_url.ex` |
| Modify | `mix.exs` (rename app, update deps, add application config) |
