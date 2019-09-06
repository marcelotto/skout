defmodule Skout.YAML.DecoderTest do
  use Skout.Test.Case
  doctest Skout.YAML.Decoder

  import Skout.YAML.Decoder, only: [decode: 1, decode: 2]

  test "empty SKOS outline" do
    assert decode("", base_iri: ex_base_iri()) ==
             {:ok,
              %Skout.Outline{
                manifest: ex_manifest(concept_scheme: ex_base_iri()),
                skos:
                  Graph.new(ex_concept_scheme_statements(),
                    prefixes: %{"" => ex_manifest().base_iri, skos: SKOS}
                  )
              }}
  end

  test "simple SKOS outline" do
    assert decode(
             """
             Foo:
             - Bar
             - baz baz:
               - qux:
                 - quux:
             """,
             base_iri: ex_base_iri()
           ) ==
             {:ok,
              %Skout.Outline{
                manifest: ex_manifest(concept_scheme: ex_base_iri()),
                skos: ex_skos()
              }}

    assert decode(
             """
             - Foo:
               - Bar
               - baz baz:
                 - qux:
                   - quux:
             """,
             base_iri: ex_base_iri()
           ) ==
             {:ok,
              %Skout.Outline{
                manifest: ex_manifest(concept_scheme: ex_base_iri()),
                skos: ex_skos()
              }}

    assert decode(
             """
             - Foo
             """,
             base_iri: ex_base_iri()
           ) ==
             {:ok,
              %Skout.Outline{
                manifest: ex_manifest(concept_scheme: ex_base_iri()),
                skos:
                  Graph.new(prefixes: %{"" => ex_base_iri(), skos: SKOS})
                  |> Graph.add(
                    ex_base_iri()
                    |> RDF.type(SKOS.ConceptScheme)
                    |> SKOS.hasTopConcept(EX.Foo)
                  )
                  |> Graph.add(
                    EX.Foo
                    |> RDF.type(SKOS.Concept)
                    |> SKOS.prefLabel(~L"Foo")
                    |> SKOS.topConceptOf(ex_base_iri())
                    |> SKOS.inScheme(ex_base_iri())
                  )
              }}
  end

  test "simple SKOS outline without hyphens in the hierarchy" do
    assert decode(
             """
             Foo:
               Bar:
               baz baz:
                 qux:
                   quux:
             """,
             base_iri: ex_base_iri()
           ) ==
             {:ok,
              %Skout.Outline{
                manifest: ex_manifest(concept_scheme: ex_base_iri()),
                skos: ex_skos()
              }}
  end

  test "simple SKOS outline with preamble" do
    assert decode(
             """
             default_language:
             ---
             Foo:
             - Bar
             - baz baz:
               - qux:
                 - quux
             """,
             base_iri: ex_base_iri()
           ) ==
             {:ok,
              %Skout.Outline{
                manifest: ex_manifest(concept_scheme: ex_base_iri()),
                skos: ex_skos()
              }}
  end

  test "SKOS outline with concept description with known properties" do
    assert decode(
             """
             Foo:
             - :a: <http://example.com/vocab/Class>
             - :related: other Foo
             - :altLabel: AltFoo
             - Bar:
               - :related:
                 - other Bar
             - baz baz:
               - qux:
                 - quux:
                   - :related: other quux
                 - :related:
                   - other qux
                   - yet another qux
               - :related: other baz
             """,
             base_iri: ex_base_iri()
           ) ==
             {:ok,
              %Skout.Outline{
                manifest: ex_manifest(concept_scheme: ex_base_iri()),
                skos:
                  ex_skos([
                    {EX.Foo, RDF.type(), ~I<http://example.com/vocab/Class>},
                    {EX.otherFoo(), RDF.type(), SKOS.Concept},
                    {EX.otherBar(), RDF.type(), SKOS.Concept},
                    {EX.otherBaz(), RDF.type(), SKOS.Concept},
                    {EX.otherQux(), RDF.type(), SKOS.Concept},
                    {EX.yetAnotherQux(), RDF.type(), SKOS.Concept},
                    {EX.otherQuux(), RDF.type(), SKOS.Concept},
                    {EX.quux(), RDF.type(), SKOS.Concept},
                    {EX.otherFoo(), SKOS.inScheme(), ex_base_iri()},
                    {EX.otherBar(), SKOS.inScheme(), ex_base_iri()},
                    {EX.otherBaz(), SKOS.inScheme(), ex_base_iri()},
                    {EX.otherQux(), SKOS.inScheme(), ex_base_iri()},
                    {EX.yetAnotherQux(), SKOS.inScheme(), ex_base_iri()},
                    {EX.otherQuux(), SKOS.inScheme(), ex_base_iri()},
                    {EX.otherFoo(), SKOS.topConceptOf(), ex_base_iri()},
                    {EX.otherBar(), SKOS.topConceptOf(), ex_base_iri()},
                    {EX.otherBaz(), SKOS.topConceptOf(), ex_base_iri()},
                    {EX.otherQux(), SKOS.topConceptOf(), ex_base_iri()},
                    {EX.yetAnotherQux(), SKOS.topConceptOf(), ex_base_iri()},
                    {EX.otherQuux(), SKOS.topConceptOf(), ex_base_iri()},
                    {ex_base_iri(), SKOS.hasTopConcept(), EX.otherFoo()},
                    {ex_base_iri(), SKOS.hasTopConcept(), EX.otherBar()},
                    {ex_base_iri(), SKOS.hasTopConcept(), EX.otherBaz()},
                    {ex_base_iri(), SKOS.hasTopConcept(), EX.otherQux()},
                    {ex_base_iri(), SKOS.hasTopConcept(), EX.yetAnotherQux()},
                    {ex_base_iri(), SKOS.hasTopConcept(), EX.otherQuux()},
                    {EX.otherQuux(), RDF.type(), SKOS.Concept},
                    {EX.Foo, SKOS.altLabel(), ~L"AltFoo"},
                    {EX.Foo, SKOS.related(), EX.otherFoo()},
                    {EX.otherFoo(), SKOS.related(), EX.Foo},
                    {EX.Bar, SKOS.related(), EX.otherBar()},
                    {EX.otherBar(), SKOS.related(), EX.Bar},
                    {EX.bazBaz(), SKOS.related(), EX.otherBaz()},
                    {EX.otherBaz(), SKOS.related(), EX.bazBaz()},
                    {EX.quux(), SKOS.related(), EX.otherQuux()},
                    {EX.otherQuux(), SKOS.related(), EX.quux()},
                    {EX.qux(), SKOS.related(), EX.otherQux()},
                    {EX.otherQux(), SKOS.related(), EX.qux()},
                    {EX.qux(), SKOS.related(), EX.yetAnotherQux()},
                    {EX.yetAnotherQux(), SKOS.related(), EX.qux()}
                  ])
              }}
  end

  test "concept description with known properties" do
    assert decode(
             """
             Foo:
             - :a: <http://example.com/vocab/Class>
             - :subClassOf: <http://example.com/vocab/OtherClass>
             - :definition: A foo is a ...
             - :notation: [42, true]
             - :related: Bar
             - :seeAlso:
               - <http://example.com/other/Foo>
               - <http://example.com/other/Bar>
             """,
             base_iri: ex_base_iri()
           ) ==
             {:ok,
              %Skout.Outline{
                manifest: ex_manifest(concept_scheme: ex_base_iri()),
                skos:
                  EX.Foo
                  |> RDF.type(SKOS.Concept, ~I<http://example.com/vocab/Class>)
                  |> RDFS.subClassOf(~I<http://example.com/vocab/OtherClass>)
                  |> SKOS.prefLabel(~L"Foo")
                  |> SKOS.definition(~L"A foo is a ...")
                  |> SKOS.related(EX.Bar)
                  |> SKOS.notation(RDF.true(), RDF.integer(42))
                  |> RDFS.seeAlso(
                    ~I<http://example.com/other/Foo>,
                    ~I<http://example.com/other/Bar>
                  )
                  |> SKOS.inScheme(ex_base_iri())
                  |> SKOS.topConceptOf(ex_base_iri())
                  |> Graph.new(prefixes: %{"" => ex_manifest().base_iri, skos: SKOS})
                  |> Graph.add(
                    EX.Bar
                    |> RDF.type(SKOS.Concept)
                    #                       |> SKOS.prefLabel(~L"Bar")
                    |> SKOS.inScheme(ex_base_iri())
                    |> SKOS.topConceptOf(ex_base_iri())
                    |> SKOS.related(EX.Foo)
                  )
                  |> Graph.add(ex_concept_scheme_statements())
                  |> Graph.add(
                    ex_base_iri()
                    |> RDF.type(SKOS.ConceptScheme)
                    |> SKOS.hasTopConcept(EX.Foo, EX.Bar)
                  )
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

    test "concept_scheme with iri in angle brackets" do
      assert {:ok, outline} =
               decode("concept_scheme: <http://other_example.com>\n---", base_iri: ex_base_iri())

      assert outline.manifest.concept_scheme == ~I<http://other_example.com>
    end

    test "setting the concept scheme to false prevents generating any concept scheme statements" do
      assert {:ok, outline} = decode("concept_scheme: false\n---", base_iri: ex_base_iri())
      assert outline.manifest.concept_scheme == false
    end

    test "concept_scheme with description" do
      assert """
             concept_scheme:
               id: <http://other_example.com>
               title: An example concept scheme
               definition: "A description of a concept scheme"
               creator: John Doe
               created: 2019
             ---

             """
             |> decode(base_iri: ex_base_iri()) ==
               {:ok,
                %Skout.Outline{
                  manifest: ex_manifest(concept_scheme: ~I<http://other_example.com>),
                  skos:
                    Graph.new(
                      ~I<http://other_example.com>
                      |> RDF.type(SKOS.ConceptScheme)
                      |> DC.title(~L"An example concept scheme")
                      |> SKOS.definition(~L"A description of a concept scheme")
                      |> DC.creator(~L"John Doe")
                      |> DC.created(RDF.integer(2019)),
                      prefixes: %{"" => ex_manifest().base_iri, skos: SKOS}
                    )
                }}
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
               decode(
                 """
                 base_iri: http://foo.com/
                 ---
                 Foo:
                   - bar
                 """,
                 concept_scheme: false
               )

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
