defmodule PasseurFiles do
  @moduledoc """
  MCP tools for file operations. Designed for use with Obsidian vaults
  or any directory of files.

  Configure the root directory:

      config :passeur_files, root: "/path/to/vault"
  """

  def root do
    Application.get_env(:passeur_files, :root) ||
      raise "Missing :root in :passeur_files config"
  end

  def safe_path(relative_path) do
    root_dir = root()
    full_path = Path.expand(relative_path, root_dir)

    if String.starts_with?(full_path, Path.expand(root_dir)) do
      {:ok, full_path}
    else
      {:error, "Path traversal not allowed"}
    end
  end
end
