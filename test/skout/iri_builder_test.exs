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
        assert IriBuilder.from_label(label, ex_manifest(iri_normalization: :underscore)) == iri(iri)
      end)
    end
  end
end
