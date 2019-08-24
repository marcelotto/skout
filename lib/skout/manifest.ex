defmodule Skout.Manifest do
  defstruct base_iri: nil,
            iri_normalization: :camelize,
            default_language: nil,
            materialization: %Skout.Materialization.Settings{},
            # This just serves as a cache to not have query the graph for this all the time
            concept_scheme: nil

  alias Skout.Materialization
  alias RDF.Literal

  import Skout.Helper

  def new(%__MODULE__{} = manifest), do: manifest |> validate()

  def new(opts) do
    __MODULE__
    |> struct(opts)
    |> normalize()
    |> validate()
  end

  def new!(manifest) do
    case new(manifest) do
      {:ok, manifest} -> manifest
      {:error, error} -> raise error
    end
  end

  defp validate(%{base_iri: nil}), do: {:error, "required base_iri not provided"}
  defp validate(%__MODULE__{} = manifest), do: {:ok, manifest}

  defp normalize(manifest) do
    manifest
    |> normalize_base_iri()
    |> normalize_iri_normalization()
    |> normalize_materialization()
  end

  defp normalize_base_iri(%{base_iri: nil} = manifest), do: manifest

  defp normalize_base_iri(manifest) do
    %__MODULE__{manifest | base_iri: RDF.IRI.coerce_base(manifest.base_iri)}
  end

  defp normalize_iri_normalization(%{iri_normalization: iri_normalization} = manifest)
       when is_binary(iri_normalization) do
    %__MODULE__{manifest | iri_normalization: String.to_existing_atom(manifest.iri_normalization)}
  end

  defp normalize_iri_normalization(manifest), do: manifest

  defp normalize_materialization(%{materialization: %Materialization.Settings{}} = manifest),
    do: manifest

  defp normalize_materialization(%{materialization: materialization} = manifest) do
    %__MODULE__{
      manifest
      | materialization: struct(%Materialization.Settings{}, atomize_keys(materialization))
    }
  end

  def term_to_literal(%Literal{} = literal, _), do: literal

  def term_to_literal(label, %{default_language: default_language}) do
    if default_language do
      Literal.new(label, language: default_language)
    else
      Literal.new(label)
    end
  end
end
