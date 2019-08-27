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
      import Skout.ExampleData
      import unquote(__MODULE__)

      import RDF.Sigils
    end
  end
end
