defmodule HemdalTrooper.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :hemdal_trooper,
      version: @version,
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Hemdal Trooper",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:trooper, "~> 0.3.0"},
      {:hemdal, github: "altenwald/hemdal"},

      # only for dev
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:doctor, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.14", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "Hemdal Trooper",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/hemdal_trooper",
      source_url: "https://github.com/altenwald/hemdal_trooper"
    ]
  end
end
