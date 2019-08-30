defmodule Skout.ExampleData do
  alias RDF.NS.SKOS
  alias RDF.Graph
  alias Skout.Test.Case.EX

  import RDF.Sigils

  @ex_base_iri RDF.iri(EX.__base_iri__())
  def ex_base_iri(), do: @ex_base_iri

  @ex_manifest Skout.Manifest.new!(base_iri: @ex_base_iri)
  def ex_manifest(), do: @ex_manifest
  def ex_manifest(opts), do: Map.merge(ex_manifest(), Map.new(opts))

  @ex_outline Skout.Outline.new!(@ex_manifest)
  def ex_outline(), do: @ex_outline

  @ex_concept_scheme_statements [
    {@ex_base_iri, RDF.type(), SKOS.ConceptScheme}
  ]
  def ex_concept_scheme_statements(), do: @ex_concept_scheme_statements

  @ex_skos Graph.new(
             [
               # Concepts
               {EX.Foo, RDF.type(), SKOS.Concept},
               {EX.Bar, RDF.type(), SKOS.Concept},
               {EX.bazBaz(), RDF.type(), SKOS.Concept},
               {EX.qux(), RDF.type(), SKOS.Concept},
               {EX.quux(), RDF.type(), SKOS.Concept},
               # Concept scheme
               {EX.Foo, SKOS.topConceptOf(), @ex_base_iri},
               {@ex_base_iri, SKOS.hasTopConcept(), EX.Foo},
               {EX.Foo, SKOS.inScheme(), @ex_base_iri},
               {EX.Bar, SKOS.inScheme(), @ex_base_iri},
               {EX.bazBaz(), SKOS.inScheme(), @ex_base_iri},
               {EX.qux(), SKOS.inScheme(), @ex_base_iri},
               {EX.quux(), SKOS.inScheme(), @ex_base_iri},
               # Lexical labels
               {EX.Foo, SKOS.prefLabel(), ~L"Foo"},
               {EX.Bar, SKOS.prefLabel(), ~L"Bar"},
               {EX.bazBaz(), SKOS.prefLabel(), ~L"baz baz"},
               {EX.qux(), SKOS.prefLabel(), ~L"qux"},
               {EX.quux(), SKOS.prefLabel(), ~L"quux"},
               # Semantic relations
               {EX.Foo, SKOS.narrower(), EX.Bar},
               {EX.Bar, SKOS.broader(), EX.Foo},
               {EX.Foo, SKOS.narrower(), EX.bazBaz()},
               {EX.bazBaz(), SKOS.broader(), EX.Foo},
               {EX.bazBaz(), SKOS.narrower(), EX.qux()},
               {EX.qux(), SKOS.broader(), EX.bazBaz()},
               {EX.qux(), SKOS.narrower(), EX.quux()},
               {EX.quux(), SKOS.broader(), EX.qux()}
             ] ++
               @ex_concept_scheme_statements,
             prefixes: %{"" => @ex_manifest.base_iri, skos: SKOS}
           )
  def ex_skos(), do: @ex_skos
  def ex_skos(additions), do: ex_skos() |> Graph.add(additions)

  @outline_with_circle %Skout.Outline{
    manifest: @ex_manifest,
    skos:
      RDF.Graph.new(
        [
          {EX.Foo, RDF.type(), SKOS.Concept},
          {EX.Bar, RDF.type(), SKOS.Concept},
          {EX.Foo, SKOS.prefLabel(), ~L"Foo"},
          {EX.Bar, SKOS.prefLabel(), ~L"Bar"},
          {EX.Foo, SKOS.narrower(), EX.Bar},
          {EX.Bar, SKOS.narrower(), EX.Foo}
        ],
        prefixes: %{"" => @ex_manifest.base_iri, skos: SKOS}
      )
  }
  def outline_with_circle(), do: @outline_with_circle
end
