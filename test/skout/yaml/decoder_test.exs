defmodule Skout.YAML.DecoderTest do
  use Skout.Test.Case
  doctest Skout.YAML.Decoder

  import Skout.YAML.Decoder, only: [decode: 2]

  @example_base_iri "http://example.com/skout#"
  @example_yaml_outline """
  ---
  Foo:
  - Bar
  - baz:
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
                    {EX.Foo, SKOS.narrower(), EX.Bar},
                    {EX.Bar, SKOS.broader(), EX.Foo},
                    {EX.Foo, SKOS.narrower(), EX.baz()},
                    {EX.baz(), SKOS.broader(), EX.Foo},
                    {EX.baz(), SKOS.narrower(), EX.qux()},
                    {EX.qux(), SKOS.broader(), EX.baz()},
                    {EX.qux(), SKOS.narrower(), EX.quux()},
                    {EX.quux(), SKOS.broader(), EX.qux()}
                  ])
              }}
  end
end
