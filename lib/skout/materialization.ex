defmodule Skout.Materialization do
  defmodule Settings do
    defstruct rdf_type: true,
              inverse_hierarchy: true,
              inverse_related: true
  end

  alias RDF.NS.SKOS

  @broader SKOS.broader()
  @narrower SKOS.narrower()
  @related SKOS.related()

  def infer({subject, @broader, object} = triple, %{inverse_hierarchy: true} = settings) do
    {object, @narrower, subject}
    |> continue(triple, settings, :inverse_hierarchy)
  end

  def infer({subject, @narrower, object} = triple, %{inverse_hierarchy: true} = settings) do
    {object, @broader, subject}
    |> continue(triple, settings, :inverse_hierarchy)
  end

  def infer({subject, @related, object} = triple, %{inverse_related: true} = settings) do
    {object, @related, subject}
    |> continue(triple, settings, :inverse_related)
  end

  def infer(triple, _), do: [triple]

  defp continue(materialization, triple, settings, finished) do
    [
      materialization
      | infer(triple, Map.put(settings, finished, false))
    ]
  end
end
