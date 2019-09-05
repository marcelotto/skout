defmodule Skout.YAML.EncoderTest do
  use Skout.Test.Case
  doctest Skout.YAML.Encoder

  import Skout.YAML.Encoder, only: [encode: 1]

  @example_outline %Skout.Outline{
    manifest: ex_manifest(),
    skos: ex_skos()
  }

  test "empty SKOS outline" do
    outline = %Skout.Outline{
      manifest: ex_manifest(),
      skos: RDF.Graph.new()
    }

    assert encode(outline) ==
             {:ok,
              """
              base_iri: #{outline.manifest.base_iri}
              iri_normalization: #{outline.manifest.iri_normalization}
              ---

              """}
  end

  test "non-empty SKOS outline" do
    assert encode(@example_outline) ==
             {:ok,
              """
              base_iri: #{@example_outline.manifest.base_iri}
              iri_normalization: #{@example_outline.manifest.iri_normalization}
              ---
              Foo:
              - Bar:
              - baz baz:
                - qux:
                  - quux:

              """}
  end

  test "SKOS outline with descriptions" do
    assert encode(
             @example_outline
             |> Skout.Outline.update_graph(fn skos ->
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
              base_iri: #{@example_outline.manifest.base_iri}
              iri_normalization: #{@example_outline.manifest.iri_normalization}
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

  test "SKOS outline with circles" do
    assert_raise RuntimeError, ~r/concept scheme contains a circle/, fn ->
      encode(outline_with_circle())
    end
  end

  describe "preamble" do
    test "concept_scheme" do
      outline = %Skout.Outline{
        manifest: ex_manifest(concept_scheme: "http://example.com/foo#"),
        skos: RDF.Graph.new()
      }

      assert encode(outline) ==
               {:ok,
                """
                base_iri: #{outline.manifest.base_iri}
                concept_scheme: http://example.com/foo#
                iri_normalization: #{outline.manifest.iri_normalization}
                ---

                """}
    end

    test "suppressed concept_scheme" do
      outline = %Skout.Outline{
        manifest: ex_manifest(concept_scheme: false),
        skos: RDF.Graph.new()
      }

      assert encode(outline) ==
               {:ok,
                """
                base_iri: #{outline.manifest.base_iri}
                iri_normalization: #{outline.manifest.iri_normalization}
                ---

                """}
    end

    test "concept scheme with descriptions" do
      outline = %Skout.Outline{
        manifest: ex_manifest(concept_scheme: "http://example.com/foo#"),
        skos:
          RDF.Graph.new(
            ~I<http://example.com/foo#>
            |> RDF.type(SKOS.ConceptScheme)
            |> DC.title(~L"An example concept scheme")
            |> SKOS.definition(~L"A description of a concept scheme")
            |> DC.creator(~L"John Doe")
            |> DC.created(RDF.integer(2019))
            # This is an unknown property and should be ignored.
            |> EX.foo(42)
          )
      }

      assert encode(outline) ==
               {:ok,
                """
                base_iri: #{outline.manifest.base_iri}
                concept_scheme:
                  id: http://example.com/foo#
                  title: An example concept scheme
                  creator: John Doe
                  created: 2019
                  definition: A description of a concept scheme
                iri_normalization: #{outline.manifest.iri_normalization}
                ---

                """}
    end

    test "default_language" do
      outline = %Skout.Outline{
        manifest: ex_manifest(default_language: "en"),
        skos: RDF.Graph.new()
      }

      assert encode(outline) ==
               {:ok,
                """
                base_iri: #{outline.manifest.base_iri}
                default_language: en
                iri_normalization: #{outline.manifest.iri_normalization}
                ---

                """}
    end
  end
end
