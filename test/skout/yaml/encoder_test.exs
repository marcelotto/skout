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
