# Passeur Files

MCP file editing tools for [Passeur](https://github.com/jfim/passeur). Provides tools for listing, reading, writing, editing, and deleting files. Designed for use with Obsidian vaults or any directory of files.

## Tools

| Tool | Description |
|------|-------------|
| `list_files` | List files and directories, with optional glob pattern filtering |
| `read_file` | Read the contents of a file |
| `write_file` | Create or overwrite a file |
| `edit_file` | Edit a file by replacing a string (search & replace) |
| `delete_file` | Delete a file |

All paths are relative to the configured root directory. Path traversal outside the root is prevented.

## Usage

Add to your MCP server project:

```elixir
# mix.exs
{:passeur_files, path: "../passeur_files"}
```

Configure the root directory via an environment variable in your host app:

```elixir
# config/runtime.exs
config :passeur_files, root: System.get_env("VAULT_PATH") || raise "VAULT_PATH not set"
```

Or with a static path for development:

```elixir
# config/dev.exs
config :passeur_files, root: "/path/to/obsidian/vault"
```

Register the tools in your MCP server:

```elixir
defmodule MyServer.MCPServer do
  use Hermes.Server,
    name: "MyServer",
    version: "0.1.0",
    capabilities: [:tools]

  component PasseurFiles.Tools.ListFiles
  component PasseurFiles.Tools.ReadFile
  component PasseurFiles.Tools.WriteFile
  component PasseurFiles.Tools.EditFile
  component PasseurFiles.Tools.DeleteFile

  @impl true
  def init(_client_info, frame), do: {:ok, frame}
end
```

## License

MIT
