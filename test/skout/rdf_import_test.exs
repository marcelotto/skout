defmodule Skout.RDF.ImportTest do
  use Skout.Test.Case
  doctest Skout.RDF.Import

  import Skout.RDF.Import

  describe "base_iri" do
    test "detection of base_iri" do
      [
        {[EX.Foo], ex_base_iri()},
        {[~I<http://example.com/foo/bar>], ~I<http://example.com/foo/>},
        {[~I<http://example.com/foo#bar>], ~I<http://example.com/foo#>},
        {[~I<http://example.com/foo#>, ~I<http://example.com/foo#bar>],
         ~I<http://example.com/foo#>}
      ]
      |> Enum.each(fn {concepts, expected_base_iri} ->
        assert {:ok, document} =
                 Graph.new(
                   Enum.map(concepts, fn concept -> {concept, RDF.type(), SKOS.Concept} end)
                 )
                 |> call()

        assert document.manifest.base_iri == expected_base_iri
      end)

      [
        ~I<http://example.com/foo/>,
        ~I<http://example.com/foo#>
      ]
      |> Enum.each(fn concept ->
        assert {:error, "could not determine a base iri"} =
                 Graph.new({concept, RDF.type(), SKOS.Concept}) |> call()
      end)
    end

    test "when concepts from different namespaces are detected" do
    end

    test "when concepts don't match the given base_iri" do
      assert {:error, _} =
               Graph.new({EX.Foo, RDF.type(), SKOS.Concept})
               |> call(base_iri: "http://example.com/other")
    end
  end

  describe "extraction of concepts and inference" do
    test "with SKOS statements only" do
      expected_skos =
        Graph.new(
          [
            {EX.Foo, RDF.type(), SKOS.Concept},
            {EX.Bar, RDF.type(), SKOS.Concept},
            {EX.Foo, SKOS.narrower(), EX.Bar},
            {EX.Bar, SKOS.broader(), EX.Foo}
          ],
          prefixes: default_prefixes()
        )

      assert {:ok, document} = Graph.new({EX.Foo, SKOS.narrower(), EX.Bar}) |> call()
      assert document.skos == expected_skos

      assert {:ok, document} = Graph.new({EX.Bar, SKOS.broader(), EX.Foo}) |> call()
      assert document.skos == expected_skos
    end
  end

  describe "concept scheme" do
    test "detection of concept scheme" do
      assert {:ok, document} =
               call(Graph.new({EX.Foo, RDF.type(), SKOS.ConceptScheme}), base_iri: EX)

      assert document.manifest.concept_scheme == iri(EX.Foo)

      assert {:ok, document} = call(Graph.new({EX.Foo, SKOS.inScheme(), EX.Bar}), base_iri: EX)
      assert document.manifest.concept_scheme == iri(EX.Bar)

      assert {:ok, document} = call(Graph.new({EX.Foo, SKOS.inScheme(), EX.Bar}), base_iri: EX)
      assert document.manifest.concept_scheme == iri(EX.Bar)
    end

    test "when concepts from different concept schemes are detected" do
      assert {:error, _} =
               call(
                 Graph.new([
                   {EX.Foo, RDF.type(), SKOS.ConceptScheme},
                   {EX.Bar, RDF.type(), SKOS.ConceptScheme}
                 ])
               )
    end

    test "when given as opt" do
      assert {:ok, document} =
               call(Graph.new({EX.Foo, RDF.type(), SKOS.ConceptScheme}),
                 concept_scheme: EX.bar(),
                 base_iri: EX
               )

      assert document.manifest.concept_scheme == EX.bar()

      assert {:ok, document} =
               call(
                 Graph.new([
                   {EX.Foo, RDF.type(), SKOS.ConceptScheme},
                   {EX.Bar, RDF.type(), SKOS.ConceptScheme}
                 ]),
                 concept_scheme: EX.baz(),
                 base_iri: EX
               )

      assert document.manifest.concept_scheme == EX.baz()
    end
  end
end
