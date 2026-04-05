defmodule PasseurFetch.MixProject do
  use Mix.Project

  def project do
    [
      app: :passeur_fetch,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "MCP tool for fetching web pages and extracting readable content",
      package: package(),
      source_url: "https://github.com/jfim/passeur_fetch"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PasseurFetch.Application, []}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/jfim/passeur_fetch"}
    ]
  end

  defp deps do
    [
      {:hermes_mcp, "~> 0.14.1"},
      {:jason, "~> 1.4"},
      {:readability, "~> 0.12.1"},
      {:htmd, "~> 0.2.0"},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end
end
