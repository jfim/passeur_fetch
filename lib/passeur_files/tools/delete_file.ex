defmodule PasseurFiles.Tools.DeleteFile do
  @moduledoc "Delete a file"

  use Hermes.Server.Component, type: :tool

  schema do
    field :path, {:required, :string}, description: "Relative path to the file to delete"
  end

  @impl true
  def execute(%{path: path}, frame) do
    case PasseurFiles.safe_path(path) do
      {:ok, full_path} ->
        case File.rm(full_path) do
          :ok ->
            {:reply,
             Hermes.Server.Response.tool()
             |> Hermes.Server.Response.text("Deleted #{path}"),
             frame}

          {:error, reason} ->
            {:reply,
             Hermes.Server.Response.tool()
             |> Hermes.Server.Response.text("Error deleting file: #{reason}"),
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
