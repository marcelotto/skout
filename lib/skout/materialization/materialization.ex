defmodule Skout.Materialization do
  alias RDF.NS.SKOS

  @broader SKOS.broader()
  @narrower SKOS.narrower()
  @related SKOS.related()

  def apply({subject, @broader, object} = triple, %{inverse_hierarchy: true}) do
    [triple, {object, @narrower, subject}]
  end

  def apply({subject, @narrower, object} = triple, %{inverse_hierarchy: true}) do
    [triple, {object, @broader, subject}]
  end

  def apply({subject, @related, object} = triple, %{inverse_related: true}) do
    [triple, {object, @related, subject}]
  end

  def apply(triple, _), do: triple
end
