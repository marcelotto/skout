defmodule Skout.Manifest do
  defstruct base_iri: nil,
            iri_normalization: :camelize,
            default_language: nil,
            materialization: %Skout.Materialization.Settings{}

  alias RDF.Literal

  def new(%__MODULE__{} = manifest), do: manifest

  def new(opts) do
    %Skout.Manifest{
      base_iri: opts |> Keyword.fetch!(:base_iri) |> RDF.IRI.coerce_base()
    }
  end

  def term_to_literal(%Literal{} = literal, _), do: literal

  def term_to_literal(label, %{default_language: default_language}) do
    if default_language do
      Literal.new(label, language: default_language)
    else
      Literal.new(label)
    end
  end
end
