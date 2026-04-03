defmodule PasseurFiles.Tools.EditFile do
  @moduledoc "Edit a file by replacing a string with another"

  use Hermes.Server.Component, type: :tool

  schema do
    field :path, {:required, :string}, description: "Relative path to the file"
    field :old_string, {:required, :string}, description: "Text to find and replace"
    field :new_string, {:required, :string}, description: "Replacement text"
  end

  @impl true
  def execute(%{path: path, old_string: old_string, new_string: new_string}, frame) do
    case PasseurFiles.safe_path(path) do
      {:ok, full_path} ->
        case File.read(full_path) do
          {:ok, content} ->
            if String.contains?(content, old_string) do
              new_content = String.replace(content, old_string, new_string, global: false)

              case File.write(full_path, new_content) do
                :ok ->
                  {:reply,
                   Hermes.Server.Response.tool()
                   |> Hermes.Server.Response.text("Edited #{path}"),
                   frame}

                {:error, reason} ->
                  {:reply,
                   Hermes.Server.Response.tool()
                   |> Hermes.Server.Response.text("Error writing file: #{reason}"),
                   frame}
              end
            else
              {:reply,
               Hermes.Server.Response.tool()
               |> Hermes.Server.Response.text("Error: old_string not found in file"),
               frame}
            end

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
