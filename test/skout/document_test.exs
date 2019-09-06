defmodule Skout.DocumentTest do
  use Skout.Test.Case
  doctest Skout.Document

  alias Skout.Document

  describe "add/2" do
    test "with a valid triple of plain strings using the narrower property" do
      assert Document.add(ex_document(), {iri(EX.Foo), SKOS.narrower(), iri(EX.Bar)}) ==
               {:ok,
                %Document{
                  ex_document()
                  | skos:
                      RDF.graph(
                        [
                          {EX.Foo, RDF.type(), SKOS.Concept},
                          {EX.Foo, SKOS.narrower(), EX.Bar},
                          {EX.Bar, RDF.type(), SKOS.Concept},
                          {EX.Bar, SKOS.broader(), EX.Foo}
                        ],
                        prefixes: default_prefixes()
                      )
                }}
    end

    test "with a valid triple with a literal on object position" do
      assert Document.add(ex_document(), {iri(EX.Foo), SKOS.prefLabel(), ~L"Foo"}) ==
               {:ok,
                %Document{
                  ex_document()
                  | skos:
                      RDF.graph({EX.Foo, SKOS.prefLabel(), ~L"Foo"},
                        prefixes: default_prefixes()
                      )
                }}
    end
  end
end
