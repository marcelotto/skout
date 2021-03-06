defmodule Skout.Manifest do
  @moduledoc !"""
             The settings for the `Skout.Document` serialization to YAML.
             """

  defstruct base_iri: nil,
            iri_normalization: :camelize,
            label_type: :prefLabel,
            default_language: nil,
            materialization: %Skout.Materialization.Settings{},
            # This just serves as a cache to not have query the graph for this all the time
            concept_scheme: nil,
            additional_concept_class: nil

  alias Skout.{Materialization, IriBuilder}
  alias RDF.{IRI, Literal, XSD}
  alias RDF.NS.SKOS

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
    |> normalize_label_type()
    |> normalize_iri_normalization()
    |> normalize_additional_concept_class()
    |> normalize_materialization()
  end

  defp normalize_base_iri(%{base_iri: nil} = manifest), do: manifest

  defp normalize_base_iri(manifest) do
    %__MODULE__{manifest | base_iri: IRI.coerce_base(manifest.base_iri)}
  end

  defp normalize_label_type(%{label_type: label_type} = manifest)
       when is_binary(label_type) do
    %__MODULE__{manifest | label_type: String.to_atom(manifest.label_type)}
  end

  defp normalize_label_type(manifest), do: manifest

  defp normalize_additional_concept_class(%{additional_concept_class: nil} = manifest),
    do: manifest

  defp normalize_additional_concept_class(%{additional_concept_class: "<" <> iri} = manifest) do
    %__MODULE__{
      manifest
      | additional_concept_class: iri |> String.slice(0..-2) |> IRI.new()
    }
  end

  defp normalize_additional_concept_class(manifest) do
    %__MODULE__{
      manifest
      | additional_concept_class:
          if IRI.absolute?(manifest.additional_concept_class) do
            IRI.new(manifest.additional_concept_class)
          else
            IriBuilder.from_label(manifest.additional_concept_class, manifest)
          end
    }
  end

  defp normalize_iri_normalization(%{iri_normalization: iri_normalization} = manifest)
       when is_binary(iri_normalization) do
    %__MODULE__{manifest | iri_normalization: String.to_atom(manifest.iri_normalization)}
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

  def object_term(%IRI{} = literal, _, _), do: {:ok, literal}
  def object_term(%Literal{} = literal, _, _), do: {:ok, literal}

  def object_term(object, _, _) when is_boolean(object), do: {:ok, XSD.boolean(object)}
  def object_term(object, _, _) when is_number(object), do: {:ok, RDF.literal(object)}

  def object_term("<" <> iri_string, _, _) do
    iri =
      iri_string
      |> String.slice(0..-2)
      |> RDF.iri()

    if IRI.valid?(iri) do
      {:ok, iri}
    else
      {:error, "Invalid IRI: <#{iri_string}"}
    end
  end

  def object_term(":" <> concept, _, %__MODULE__{} = manifest) do
    {:ok, IriBuilder.from_label(concept, manifest)}
  end

  @props_with_range_concept Materialization.semantic_relations() ++
                              Materialization.props_with_range_concept()

  def object_term(concept, property, manifest)
      when is_binary(concept) and property in @props_with_range_concept do
    {:ok, IriBuilder.from_label(concept, manifest)}
  end

  def object_term(string, _, _) when is_binary(string), do: {:ok, XSD.string(string)}

  def label_property(%__MODULE__{label_type: :prefLabel}), do: SKOS.prefLabel()
  def label_property(%__MODULE__{label_type: :notation}), do: SKOS.notation()
end
