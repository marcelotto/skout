defmodule Skout.YAML.DecoderTest do
  use Skout.Test.Case
  doctest Skout.YAML.Decoder

  import Skout.YAML.Decoder, only: [decode: 1, decode: 2]

  @example_yaml_outline """
  Foo:
  - Bar
  - baz baz:
    - qux:
      - quux
  """

  @example_yaml_outline_with_preamble """
  default_language:
  ---
  Foo:
  - Bar
  - baz baz:
    - qux:
      - quux
  """
  @example_skos RDF.Graph.new([
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
                ])

  test "empty SKOS outline" do
    assert decode("", base_iri: ex_base_iri()) ==
             {:ok,
              %Skout.Outline{
                manifest: ex_manifest(),
                skos: RDF.Graph.new()
              }}
  end

  test "simple SKOS outline" do
    assert decode(@example_yaml_outline, base_iri: ex_base_iri()) ==
             {:ok,
              %Skout.Outline{
                manifest: ex_manifest(),
                skos: @example_skos
              }}
  end

  test "simple SKOS outline with preamble" do
    assert decode(@example_yaml_outline_with_preamble, base_iri: ex_base_iri()) ==
             {:ok,
              %Skout.Outline{
                manifest: ex_manifest(),
                skos: @example_skos
              }}
  end

  describe "preamble" do
    test "setting the base_iri" do
      assert {:ok, outline} =
               decode("""
               base_iri: http://foo.com/
               ---
               Foo:
                 - bar
               """)

      assert outline.manifest.base_iri == ~I<http://foo.com/>
    end

    test "setting the base_iri with the base alias" do
      assert {:ok, outline} =
               decode("""
               base: http://foo.com/
               ---
               Foo:
                 - bar
               """)

      assert outline.manifest.base_iri == ~I<http://foo.com/>
    end

    test "setting the default_language" do
      assert {:ok, outline} =
               decode(
                 """
                 default_language: en
                 ---
                 Foo:
                   - bar
                 """,
                 base_iri: ex_base_iri()
               )

      assert outline.manifest.default_language == "en"

      assert {:ok, outline} =
               decode(
                 """
                 default_language:
                 ---
                 Foo:
                   - bar
                 """,
                 base_iri: ex_base_iri()
               )

      assert outline.manifest.default_language == nil
    end

    test "setting the iri_normalization" do
      assert {:ok, outline} =
               decode(
                 """
                 iri_normalization: underscore
                 ---
                 Foo:
                   - bar
                 """,
                 base_iri: ex_base_iri()
               )

      assert outline.manifest.iri_normalization == :underscore
    end

    test "setting the materialization opts" do
      assert {:ok, outline} =
               decode(
                 """
                 materialization:
                   - inverse_hierarchy: false
                   - inverse_related: false
                 ---
                 Foo:
                   - bar
                 """,
                 base_iri: ex_base_iri()
               )

      assert outline.manifest.materialization.inverse_hierarchy == false
      assert outline.manifest.materialization.inverse_related == false
    end

    test "decode opts overwrite preamble opts" do
      assert {:ok, outline} =
               decode(
                 """
                 base: http://foo.com/
                 iri_normalization: camelize
                 default_language: en
                 materialization:
                   - inverse_hierarchy: true
                   - inverse_related: true
                 ---
                 Foo:
                   - bar
                 """,
                 base_iri: ex_base_iri(),
                 iri_normalization: :underscore,
                 default_language: "de",
                 materialization: %{
                   inverse_hierarchy: false,
                   inverse_related: false
                 }
               )

      assert outline.manifest.base_iri == ex_base_iri()
      assert outline.manifest.default_language == "de"
      assert outline.manifest.iri_normalization == :underscore
      assert outline.manifest.materialization.inverse_hierarchy == false
      assert outline.manifest.materialization.inverse_related == false
    end
  end
end
