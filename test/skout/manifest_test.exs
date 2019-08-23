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
end
