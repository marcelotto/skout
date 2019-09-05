defmodule Skout.IriBuilderTest do
  use Skout.Test.Case
  doctest Skout.IriBuilder

  alias Skout.IriBuilder

  describe "from_label/2" do
    test "with IRI" do
      assert IriBuilder.from_label(EX.foo(), ex_manifest()) == EX.foo()
    end

    test "with simple term" do
      assert IriBuilder.from_label("Foo", ex_manifest()) == iri(EX.Foo)
      assert IriBuilder.from_label("bar", ex_manifest()) == EX.bar()

      assert IriBuilder.from_label("Bar", ~I<http://example.com/foo#>, :camelize) ==
               ~I<http://example.com/foo#Bar>
    end

    test "with a term with whitespace and manifest.iri_normalization == :camelize (default)" do
      %{
        "Foo bar" => EX.FooBar,
        "foo bar" => EX.fooBar(),
        "foo 1" => EX.foo1(),
        "foo #1" => EX.foo1()
      }
      |> Enum.each(fn {label, iri} ->
        assert IriBuilder.from_label(label, ex_manifest()) == iri(iri)
      end)
    end

    test "with a term with whitespace and manifest.iri_normalization == :underscore" do
      %{
        "Foo bar" => EX.foo_bar(),
        "foo bar" => EX.foo_bar(),
        "foo 1" => EX.foo_1(),
        "foo #1" => EX.foo_1()
      }
      |> Enum.each(fn {label, iri} ->
        assert IriBuilder.from_label(label, ex_manifest(iri_normalization: :underscore)) ==
                 iri(iri)
      end)
    end

  describe "predicate_to_iri/2" do
    test "with IRI" do
      assert IriBuilder.predicate(SKOS.broader(), ex_manifest()) == {:ok, SKOS.broader()}
    end

    test "with known property" do
      assert IriBuilder.predicate("notation", ex_manifest()) == {:ok, SKOS.notation()}
      assert IriBuilder.predicate("definition", ex_manifest()) == {:ok, SKOS.definition()}
      assert IriBuilder.predicate("related", ex_manifest()) == {:ok, SKOS.related()}
      assert IriBuilder.predicate("a", ex_manifest()) == {:ok, RDF.type()}
      assert IriBuilder.predicate("subClassOf", ex_manifest()) == {:ok, RDFS.subClassOf()}
      assert IriBuilder.predicate("seeAlso", ex_manifest()) == {:ok, RDFS.seeAlso()}
      assert IriBuilder.predicate("isDefinedBy", ex_manifest()) == {:ok, RDFS.isDefinedBy()}
      assert IriBuilder.predicate("title", ex_manifest()) == {:ok, DC.title()}
      assert IriBuilder.predicate("creator", ex_manifest()) == {:ok, DC.creator()}
    end

    test "with unknown property" do
      assert IriBuilder.predicate("unknown", ex_manifest()) ==
               {:error, "Unknown property 'unknown'"}
    end
  end
end
