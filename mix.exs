defmodule HemdalTrooper.MixProject do
  use Mix.Project

  @version "1.0.4"

  def project do
    [
      app: :hemdal_trooper,
      description: "Hemdal Trooper extension",
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Hemdal Trooper",
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp deps do
    [
      {:trooper, "~> 0.4"},
      {:hemdal, "~> 1.0"},

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

  defp package do
    [
      files: ~w[ lib mix.* COPYING ],
      maintainers: ["Manuel Rubio"],
      licenses: ["LGPL-2.1-only"],
      links: %{
        "GitHub" => "https://github.com/altenwald/hemdal",
        "Docs" => "https://hexdocs.pm/hemdal"
      }
    ]
  end
end
