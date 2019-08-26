defmodule Skout.MixProject do
  use Mix.Project

  def project do
    [
      app: :skout,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # {:rdf, "~> 0.6.2"},
      {:rdf, path: "../../../RDF.ex/src/rdf"},
      # {:sparql, "~> 0.3"},
      {:sparql, path: "../../../RDF.ex/src/sparql"},
      {:yaml_elixir, "~> 2.4"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
