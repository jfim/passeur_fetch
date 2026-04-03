defmodule PasseurFiles.MixProject do
  use Mix.Project

  def project do
    [
      app: :passeur_files,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "MCP file editing tools for Passeur",
      package: package(),
      source_url: "https://github.com/jfim/passeur_files"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def description do
    "MCP file editing tools for Passeur. List, read, write, edit, and delete files."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/jfim/passeur_files"}
    ]
  end

  defp deps do
    [
      {:hermes_mcp, "~> 0.14.1"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end
end
