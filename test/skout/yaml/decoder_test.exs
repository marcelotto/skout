defmodule Skout.YAML.DecoderTest do
  use Skout.Test.Case
  doctest Skout.YAML.Decoder

  import Skout.YAML.Decoder, only: [decode: 2]

  @example_base_iri "http://example.com/skout#"
  @example_yaml_outline """
  ---
  Foo:
  - Bar
  - baz baz:
    - qux:
      - quux
  """

  test "simple SKOS outline" do
    assert decode(@example_yaml_outline, base_iri: @example_base_iri) ==
             {:ok,
              %Skout.Outline{
                manifest: %Skout.Manifest{base_iri: @example_base_iri},
                skos:
                  RDF.Graph.new([
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
                  ])
              }}
  end
end
