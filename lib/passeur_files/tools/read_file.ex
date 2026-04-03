defmodule PasseurFiles.Tools.ReadFile do
  @moduledoc "Read the contents of a file"

  use Hermes.Server.Component, type: :tool

  schema do
    field :path, {:required, :string}, description: "Relative path to the file"
  end

  @impl true
  def execute(%{path: path}, frame) do
    case PasseurFiles.safe_path(path) do
      {:ok, full_path} ->
        case File.read(full_path) do
          {:ok, content} ->
            {:reply,
             Hermes.Server.Response.tool()
             |> Hermes.Server.Response.text(content),
             frame}

          {:error, reason} ->
            {:reply,
             Hermes.Server.Response.tool()
             |> Hermes.Server.Response.text("Error reading file: #{reason}"),
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
