defmodule Skout.MixProject do
  use Mix.Project

  @version File.read!("VERSION") |> String.trim()

  def project do
    [
      app: :skout,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      escript: [main_module: Skout.CLI],
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rdf, "~> 0.6.2"},
      {:sparql, "~> 0.3.2"},
      {:json_ld, "~> 0.3"},
      {:yaml_elixir, "~> 2.4"},
      {:optimus, "~> 0.1"},
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
