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

  @example_concept_scheme_statements [
    {ex_base_iri(), RDF.type(), SKOS.ConceptScheme}
  ]

  @example_skos RDF.Graph.new(
                  [
                    # Concepts
                    {EX.Foo, RDF.type(), SKOS.Concept},
                    {EX.Bar, RDF.type(), SKOS.Concept},
                    {EX.bazBaz(), RDF.type(), SKOS.Concept},
                    {EX.qux(), RDF.type(), SKOS.Concept},
                    {EX.quux(), RDF.type(), SKOS.Concept},
                    # Concept scheme
                    {EX.Foo, SKOS.topConceptOf(), ex_base_iri()},
                    {ex_base_iri(), SKOS.hasTopConcept(), EX.Foo},
                    {EX.Foo, SKOS.inScheme(), ex_base_iri()},
                    {EX.Bar, SKOS.inScheme(), ex_base_iri()},
                    {EX.bazBaz(), SKOS.inScheme(), ex_base_iri()},
                    {EX.qux(), SKOS.inScheme(), ex_base_iri()},
                    {EX.quux(), SKOS.inScheme(), ex_base_iri()},
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
                    @example_concept_scheme_statements
                )

  test "empty SKOS outline" do
    assert decode("", base_iri: ex_base_iri()) ==
             {:ok,
              %Skout.Outline{
                manifest: ex_manifest(concept_scheme: ex_base_iri()),
                skos: RDF.Graph.new(@example_concept_scheme_statements)
              }}
  end

  test "simple SKOS outline" do
    assert decode(@example_yaml_outline, base_iri: ex_base_iri()) ==
             {:ok,
              %Skout.Outline{
                manifest: ex_manifest(concept_scheme: ex_base_iri()),
                skos: @example_skos
              }}
  end

  test "simple SKOS outline with preamble" do
    assert decode(@example_yaml_outline_with_preamble, base_iri: ex_base_iri()) ==
             {:ok,
              %Skout.Outline{
                manifest: ex_manifest(concept_scheme: ex_base_iri()),
                skos: @example_skos
              }}
  end


  describe "concept scheme" do
    test "without the concept_scheme the base_iri is used" do
      assert {:ok, outline} = decode("", base_iri: ex_base_iri())
      assert outline.manifest.concept_scheme == ex_base_iri()
    end

    test "concept_scheme with simple term" do
      assert {:ok, outline} = decode("concept_scheme: Foo\n---", base_iri: ex_base_iri())
      assert outline.manifest.concept_scheme == iri(EX.Foo)
    end

    test "concept_scheme with iri" do
      assert {:ok, outline} =
               decode("concept_scheme: http://other_example.com\n---", base_iri: ex_base_iri())

      assert outline.manifest.concept_scheme == ~I<http://other_example.com>
    end

    test "setting the concept scheme to false prevents generating any concept scheme statements" do
      assert {:ok, outline} = decode("concept_scheme: false\n---", base_iri: ex_base_iri())
      assert outline.manifest.concept_scheme == false
    end
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

    test "setting the concept_scheme" do
      assert {:ok, outline} =
               decode("""
               base_iri: http://foo.com/
               ---
               Foo:
                 - bar
               """, concept_scheme: false)

      assert outline.manifest.concept_scheme == false
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
