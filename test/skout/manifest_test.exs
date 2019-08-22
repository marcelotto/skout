defmodule Skout.ManifestTest do
  use Skout.Test.Case
  doctest Skout.Manifest

  alias Skout.Manifest

  describe "new/1" do
    test "initializing the base_iri" do
      expected_base_iri = iri(EX.__base_iri__())
      assert Manifest.new(base_iri: iri(EX.__base_iri__())).base_iri == expected_base_iri
      assert Manifest.new(base_iri: to_string(EX.__base_iri__())).base_iri == expected_base_iri
      assert Manifest.new(base_iri: EX).base_iri == expected_base_iri
    end
  end

  describe "term_to_iri/2" do
    test "with IRI" do
      assert Manifest.term_to_iri(EX.foo(), ex_manifest()) == EX.foo()
    end

    test "with simple term" do
      assert Manifest.term_to_iri("Foo", ex_manifest()) == iri(EX.Foo)
      assert Manifest.term_to_iri("bar", ex_manifest()) == EX.bar()
    end

  describe "term_to_literal/2" do
    test "with RDF.Literal" do
      assert Manifest.term_to_literal(~L"Foo", ex_manifest()) == ~L"Foo"
      assert Manifest.term_to_literal(~L"Foo"en, ex_manifest()) == ~L"Foo"en
    end

    test "with a string and no default_language set" do
      assert Manifest.term_to_literal("Foo", ex_manifest()) == ~L"Foo"
    end

    test "with a string and a default_language set" do
      assert Manifest.term_to_literal("Foo", ex_manifest(default_language: "en")) == ~L"Foo"en
    end
  end

  describe "predicate_to_iri/2" do
    test "with IRI" do
      assert Manifest.predicate_to_iri(SKOS.broader(), ex_manifest()) == SKOS.broader()
    end
  end
end
