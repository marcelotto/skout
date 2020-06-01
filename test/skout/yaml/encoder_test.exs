defmodule Skout.YAML.EncoderTest do
  use Skout.Test.Case
  doctest Skout.YAML.Encoder

  import Skout.YAML.Encoder, only: [encode: 1]

  @example_document %Skout.Document{
    manifest: ex_manifest(),
    skos: ex_skos()
  }

  test "empty Skout document" do
    document = %Skout.Document{
      manifest: ex_manifest(),
      skos: RDF.Graph.new()
    }

    assert encode(document) ==
             {:ok,
              """
              base_iri: #{document.manifest.base_iri}
              iri_normalization: #{document.manifest.iri_normalization}
              label_type: #{document.manifest.label_type}
              ---

              """}
  end

  test "non-empty Skout document" do
    assert encode(@example_document) ==
             {:ok,
              """
              base_iri: #{@example_document.manifest.base_iri}
              iri_normalization: #{@example_document.manifest.iri_normalization}
              label_type: #{@example_document.manifest.label_type}
              ---
              Foo:
              - Bar:
              - baz baz:
                - qux:
                  - quux:

              """}
  end

  test "Skout document with descriptions" do
    assert encode(
             @example_document
             |> Skout.Document.update_graph(fn skos ->
               skos
               |> Graph.add([
                 {EX.Foo, SKOS.related(), EX.qux()},
                 {EX.qux(), SKOS.related(), EX.Foo}
               ])
               |> Graph.add(
                 EX.Foo
                 |> SKOS.altLabel(42, 3.14, true, false)
               )
               |> Graph.add(
                 EX.Bar
                 |> RDF.type(EX.Type, EX.Foo)
                 |> RDFS.seeAlso(
                   ~I<http://example.com/other/Bar>,
                   ~I<http://example.com/another/Bar>,
                   ~I<http://example.com/yet_another/Bar>
                 )
               )
             end)
           ) ==
             {:ok,
              """
              base_iri: #{@example_document.manifest.base_iri}
              iri_normalization: #{@example_document.manifest.iri_normalization}
              label_type: #{@example_document.manifest.label_type}
              ---
              Foo:
              - :altLabel: [false, true, 3.14, 42]
              - :related: qux
              - Bar:
                - :a: [:Foo, <http://example.com/Type>]
                - :seeAlso:
                  - <http://example.com/another/Bar>
                  - <http://example.com/other/Bar>
                  - <http://example.com/yet_another/Bar>
              - baz baz:
                - qux:
                  - :related: Foo
                  - quux:

              """}
  end

  test "Skout document with non-default label_type" do
    assert encode(
             Skout.Document.new!(ex_manifest(label_type: :notation))
             |> Skout.Document.update_graph(fn skos ->
               skos
               |> Graph.add(
                 EX.Foo
                 |> RDF.type(SKOS.Concept)
                 |> SKOS.notation(~L"Foo")
                 |> SKOS.prefLabel(~L"FooBar")
                 |> SKOS.inScheme(ex_base_iri())
                 |> SKOS.topConceptOf(ex_base_iri())
               )
               |> Graph.add(
                 ex_base_iri()
                 |> RDF.type(SKOS.ConceptScheme)
                 |> SKOS.hasTopConcept(EX.Foo)
               )
             end)
           ) ==
             {:ok,
              """
              base_iri: #{@example_document.manifest.base_iri}
              iri_normalization: #{@example_document.manifest.iri_normalization}
              label_type: notation
              ---
              Foo:
              - :prefLabel: FooBar

              """}
  end

  test "Skout document with circles" do
    assert_raise RuntimeError, ~r/concept scheme contains a circle/, fn ->
      encode(document_with_circle())
    end
  end

  describe "preamble" do
    test "concept_scheme" do
      document = %Skout.Document{
        manifest: ex_manifest(concept_scheme: "http://example.com/foo#"),
        skos: RDF.Graph.new()
      }

      assert encode(document) ==
               {:ok,
                """
                base_iri: #{document.manifest.base_iri}
                concept_scheme: http://example.com/foo#
                iri_normalization: #{document.manifest.iri_normalization}
                label_type: #{document.manifest.label_type}
                ---

                """}
    end

    test "suppressed concept_scheme" do
      document = %Skout.Document{
        manifest: ex_manifest(concept_scheme: false),
        skos: RDF.Graph.new()
      }

      assert encode(document) ==
               {:ok,
                """
                base_iri: #{document.manifest.base_iri}
                iri_normalization: #{document.manifest.iri_normalization}
                label_type: #{document.manifest.label_type}
                ---

                """}
    end

    test "concept scheme with descriptions" do
      document = %Skout.Document{
        manifest: ex_manifest(concept_scheme: "http://example.com/foo#"),
        skos:
          RDF.Graph.new(
            ~I<http://example.com/foo#>
            |> RDF.type(SKOS.ConceptScheme)
            |> DC.title(~L"An example concept scheme")
            |> SKOS.definition(~L"A description of a concept scheme")
            |> DC.creator(~L"John Doe")
            |> DC.created(XSD.integer(2019))
            # This is an unknown property and should be ignored.
            |> EX.foo(42)
          )
      }

      assert encode(document) ==
               {:ok,
                """
                base_iri: #{document.manifest.base_iri}
                concept_scheme:
                  id: http://example.com/foo#
                  title: An example concept scheme
                  creator: John Doe
                  created: 2019
                  definition: A description of a concept scheme
                iri_normalization: #{document.manifest.iri_normalization}
                label_type: #{document.manifest.label_type}
                ---

                """}
    end

    test "label_type" do
      document = %Skout.Document{
        manifest: ex_manifest(label_type: :notation),
        skos:
          Graph.new()
          |> Graph.add(
            ex_base_iri()
            |> SKOS.prefLabel(~L"Foo")
            |> SKOS.notation(~L"bar")
          )
      }

      assert encode(document) ==
               {:ok,
                """
                base_iri: #{document.manifest.base_iri}
                iri_normalization: #{document.manifest.iri_normalization}
                label_type: notation
                ---

                """}
    end

    test "labels for the concept scheme" do
      document = %Skout.Document{
        manifest: ex_manifest(label_type: :notation, concept_scheme: ex_base_iri()),
        skos:
          Graph.new()
          |> Graph.add(
            ex_base_iri()
            |> SKOS.prefLabel(~L"Foo")
            |> SKOS.notation(~L"bar")
          )
      }

      assert encode(document) ==
               {:ok,
                """
                base_iri: #{document.manifest.base_iri}
                concept_scheme:
                  id: #{document.manifest.base_iri}
                  prefLabel: Foo
                  notation: bar
                iri_normalization: #{document.manifest.iri_normalization}
                label_type: notation
                ---

                """}
    end

    test "default_language" do
      document = %Skout.Document{
        manifest: ex_manifest(default_language: "en"),
        skos: RDF.Graph.new()
      }

      assert encode(document) ==
               {:ok,
                """
                base_iri: #{document.manifest.base_iri}
                default_language: en
                iri_normalization: #{document.manifest.iri_normalization}
                label_type: #{document.manifest.label_type}
                ---

                """}
    end
  end
end
