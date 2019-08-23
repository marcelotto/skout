defmodule Skout.Manifest do
  defstruct base_iri: nil,
            iri_normalization: :camelize,
            default_language: nil,
            materialization: %Skout.Materialization.Settings{}

  alias RDF.Literal

  def new(%__MODULE__{} = manifest), do: manifest |> validate()

  def new(opts) do
    Skout.Manifest
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
    %Skout.Manifest{
      manifest
      | base_iri: manifest.base_iri && RDF.IRI.coerce_base(manifest.base_iri),
        iri_normalization:
          if(is_binary(manifest.iri_normalization),
            do: String.to_existing_atom(manifest.iri_normalization),
            else: manifest.iri_normalization
          ),
        materialization:
          if(match?(%Skout.Materialization.Settings{}, manifest.materialization),
            do: manifest.materialization,
            else:
              struct(
                %Skout.Materialization.Settings{},
                Skout.Helper.atomize_keys(manifest.materialization)
              )
          )
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
