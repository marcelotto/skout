defmodule Skout.OutlineTest do
  use Skout.Test.Case
  doctest Skout.Outline

  alias Skout.Outline

  describe "add/2" do
    test "with a valid triple of plain strings using the narrower property" do
      assert Outline.add(ex_outline(), {iri(EX.Foo), SKOS.narrower(), iri(EX.Bar)}) ==
               {:ok,
                %Outline{
                  ex_outline()
                  | skos:
                      RDF.graph(
                        [
                          {EX.Foo, RDF.type(), SKOS.Concept},
                          {EX.Foo, SKOS.narrower(), EX.Bar},
                          {EX.Bar, RDF.type(), SKOS.Concept},
                          {EX.Bar, SKOS.broader(), EX.Foo}
                        ],
                        prefixes: %{"" => ex_manifest().base_iri, skos: SKOS}
                      )
                }}
    end

    test "with a valid triple with a literal on object position" do
      assert Outline.add(ex_outline(), {iri(EX.Foo), SKOS.prefLabel(), ~L"Foo"}) ==
               {:ok,
                %Outline{
                  ex_outline()
                  | skos:
                      RDF.graph({EX.Foo, SKOS.prefLabel(), ~L"Foo"},
                        prefixes: %{"" => ex_manifest().base_iri, skos: SKOS}
                      )
                }}
    end
  end
end
