defmodule Skout.Manifest do
  defstruct base_iri: nil,
            default_language: nil,
            materialization: %Skout.Materialization.Settings{}

  alias RDF.{IRI, Literal}

  def new(%__MODULE__{} = manifest), do: manifest

  def new(opts) do
    %Skout.Manifest{
      base_iri: opts |> Keyword.fetch!(:base_iri) |> RDF.IRI.coerce_base()
    }
  end

  def term_to_iri(%IRI{} = iri, _), do: iri

  def term_to_iri(label, manifest) do
    manifest.base_iri |> IRI.merge(label)
  end

  def term_to_literal(%Literal{} = literal, _), do: literal

  def term_to_literal(label, %{default_language: default_language}) do
    if default_language do
      Literal.new(label, language: default_language)
    else
      Literal.new(label)
    end
  end

  def predicate_to_iri(%IRI{} = iri, _), do: iri
end
