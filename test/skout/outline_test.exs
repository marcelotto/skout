defmodule Skout.OutlineTest do
  use Skout.Test.Case
  doctest Skout.Outline

  alias Skout.Outline

  describe "add/2" do
    test "with a valid triple of plain strings using the narrower property" do
      assert Outline.add(ex_outline(), {"Foo", SKOS.narrower(), "Bar"}) ==
               {:ok,
                %Outline{
                  ex_outline()
                  | skos:
                      RDF.graph([
                        {EX.Foo, SKOS.narrower(), EX.Bar},
                        {EX.Bar, SKOS.broader(), EX.Foo}
                      ])
                }}
    end
  end
end
