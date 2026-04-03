defmodule PasseurFiles.Tools.ListFiles do
  @moduledoc "List files and directories at a given path"

  use Hermes.Server.Component, type: :tool

  schema do
    field :path, :string, description: "Relative path within the vault (default: root)"
    field :pattern, :string, description: "Glob pattern to filter files (e.g. \"*.md\")"
  end

  @impl true
  def execute(args, frame) do
    relative = args[:path] || "."
    pattern = args[:pattern]

    case PasseurFiles.safe_path(relative) do
      {:ok, dir_path} ->
        entries =
          if pattern do
            Path.wildcard(Path.join(dir_path, pattern))
          else
            case File.ls(dir_path) do
              {:ok, files} -> Enum.map(files, &Path.join(dir_path, &1))
              {:error, reason} -> {:error, reason}
            end
          end

        case entries do
          {:error, reason} ->
            {:reply,
             Hermes.Server.Response.tool()
             |> Hermes.Server.Response.text("Error: #{reason}"),
             frame}

          files ->
            root = PasseurFiles.root()

            listing =
              files
              |> Enum.sort()
              |> Enum.map(fn path ->
                relative_path = Path.relative_to(path, root)
                type = if File.dir?(path), do: "dir", else: "file"
                "#{type}\t#{relative_path}"
              end)
              |> Enum.join("\n")

            {:reply,
             Hermes.Server.Response.tool()
             |> Hermes.Server.Response.text(listing),
             frame}
        end

      {:error, msg} ->
        {:reply,
         Hermes.Server.Response.tool()
         |> Hermes.Server.Response.text("Error: #{msg}"),
         frame}
    end
  end
end
