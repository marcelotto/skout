defmodule Skout.Test.Case do
  use ExUnit.CaseTemplate

  use RDF.Vocabulary.Namespace

  defvocab EX,
    base_iri: "http://example.com/",
    terms: [],
    strict: false

  using do
    quote do
      alias RDF.{Graph, Description, IRI}
      alias RDF.NS.SKOS
      alias unquote(__MODULE__).EX

      import RDF, only: [iri: 1, literal: 1]
      import unquote(__MODULE__)

      import RDF.Sigils
    end
  end

  @ex_base_iri RDF.iri(EX.__base_iri__())
  @ex_manifest Skout.Manifest.new!(base_iri: @ex_base_iri)
  @ex_outline Skout.Outline.new!(@ex_manifest)

  def ex_base_iri(), do: @ex_base_iri
  def ex_manifest(), do: @ex_manifest
  def ex_manifest(opts), do: Map.merge(ex_manifest(), Map.new(opts))
  def ex_outline(), do: @ex_outline
end
