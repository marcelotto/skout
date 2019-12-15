defmodule Skout.MixProject do
  use Mix.Project

  @repo_url "https://github.com/marcelotto/skout"

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

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rdf, "~> 0.7"},
      {:sparql, "~> 0.3.2"},
      {:json_ld, "~> 0.3"},
      {:yaml_elixir, "~> 2.4"},
      {:optimus, "~> 0.1"},
      {:ex_doc, "~> 0.20", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
