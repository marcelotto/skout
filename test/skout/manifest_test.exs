defmodule Skout.ManifestTest do
  use Skout.Test.Case
  doctest Skout.Manifest

  alias Skout.Manifest

  describe "new/1" do
    test "initializing the base_iri" do
      expected_base_iri = iri(EX.__base_iri__())
      assert Manifest.new!(base_iri: iri(EX.__base_iri__())).base_iri == expected_base_iri
      assert Manifest.new!(base_iri: to_string(EX.__base_iri__())).base_iri == expected_base_iri
      assert Manifest.new!(base_iri: EX).base_iri == expected_base_iri
    end
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

  describe "object_term/2" do
    test "with RDF.IRI" do
      assert Manifest.object_term(SKOS.related(), RDFS.seeAlso(), ex_manifest()) ==
               {:ok, SKOS.related()}
    end

    test "with RDF.Literal" do
      assert Manifest.object_term(~L"Foo", SKOS.notation(), ex_manifest()) == {:ok, ~L"Foo"}
      assert Manifest.object_term(~L"Foo"en, SKOS.notation(), ex_manifest()) == {:ok, ~L"Foo"en}
    end

    test "with an number" do
      assert Manifest.object_term(42, SKOS.notation(), ex_manifest()) == {:ok, RDF.integer(42)}
      assert Manifest.object_term(3.14, SKOS.notation(), ex_manifest()) == {:ok, RDF.double(3.14)}
    end

    test "with an boolean" do
      assert Manifest.object_term(true, SKOS.notation(), ex_manifest()) == {:ok, RDF.true()}
      assert Manifest.object_term(false, SKOS.notation(), ex_manifest()) == {:ok, RDF.false()}
    end

    test "with a string in angle brackets" do
      assert Manifest.object_term("<http://example.com/custom>", RDFS.seeAlso(), ex_manifest()) ==
               {:ok, ~I<http://example.com/custom>}

      assert Manifest.object_term("<invalid>", RDFS.seeAlso(), ex_manifest()) ==
               {:error, "Invalid IRI: <invalid>"}
    end

    test "with a string starting with a colon" do
      assert Manifest.object_term(":Foo", RDFS.seeAlso(), ex_manifest()) == {:ok, iri(EX.Foo)}
      assert Manifest.object_term(":foo", RDFS.seeAlso(), ex_manifest()) == {:ok, EX.foo()}
    end

    test "with a string as object and a property known to expect a concept" do
      assert Manifest.object_term("Foo", SKOS.related(), ex_manifest()) == {:ok, iri(EX.Foo)}
    end

    test "with any other string" do
      assert Manifest.object_term("Foo", SKOS.definition(), ex_manifest()) ==
               {:ok, RDF.string("Foo")}
    end
  end
end
