defmodule Skout.MixProject do
  use Mix.Project

  @repo_url "https://github.com/marcelotto/skout"

  @version File.read!("VERSION") |> String.trim()

  def project do
    [
      app: :skout,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      escript: [main_module: Skout.CLI],
      releases: releases(),

      # Hex
      package: package(),
      description: description(),

      # Docs
      name: "Skout",
      docs: [
        main: "Skout.Document",
        source_url: @repo_url,
        source_ref: "v#{@version}",
        extras: ["README.md", "CHANGELOG.md"]
      ]
    ]
  end

  defp description do
    """
    A terse, opinionated format for SKOS concept schemes.
    """
  end

  defp package do
    [
      maintainers: ["Marcel Otto"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @repo_url,
        "Changelog" => @repo_url <> "/blob/master/CHANGELOG.md"
      },
      files: ~w[lib priv mix.exs VERSION *.md]
    ]
  end

  defp releases do
    [
      skout: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            macos_arm: [os: :darwin, cpu: :aarch64]
          ]
        ]
      ]
    ]
  end

  def application do
    [
      mod: {Skout.CLI, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rdf, "~> 2.0"},
      {:sparql, "~> 0.3"},
      {:json_ld, "~> 1.0"},
      {:yaml_elixir, "~> 2.4"},
      {:optimus, "~> 0.1"},
      {:burrito, "~> 1.5"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
