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

  @semantic_relations [
    @related,
    @broader,
    @narrower,
    SKOS.broaderTransitive(),
    SKOS.narrowerTransitive(),
    SKOS.semanticRelation()
  ]

  @props_with_domain_concept [
    SKOS.topConceptOf()
  ]

  @props_with_range_concept [
    SKOS.hasTopConcept(),
    SKOS.member()
  ]

  def infer({subject, @broader, object} = triple, %{inverse_hierarchy: true} = settings) do
    [{object, @narrower, subject}]
    |> continue(triple, settings, :inverse_hierarchy)
  end

  def infer({subject, @narrower, object} = triple, %{inverse_hierarchy: true} = settings) do
    [{object, @broader, subject}]
    |> continue(triple, settings, :inverse_hierarchy)
  end

  def infer({subject, @related, object} = triple, %{inverse_related: true} = settings) do
    [{object, @related, subject}]
    |> continue(triple, settings, :inverse_related)
  end

  def infer({subject, predicate, object} = triple, %{rdf_type: true} = settings)
      when predicate in @semantic_relations do
    [
      {subject, RDF.type(), SKOS.Concept},
      {object, RDF.type(), SKOS.Concept}
    ]
    |> continue(triple, settings, :rdf_type)
  end

  def infer({subject, predicate, _} = triple, %{rdf_type: true} = settings)
      when predicate in @props_with_domain_concept do
    [{subject, RDF.type(), SKOS.Concept}]
    |> continue(triple, settings, :rdf_type)
  end

  def infer({_, predicate, object} = triple, %{rdf_type: true} = settings)
      when predicate in @props_with_range_concept do
    [{object, RDF.type(), SKOS.Concept}]
    |> continue(triple, settings, :rdf_type)
  end

  def infer(triple, _), do: [triple]

  defp continue(materializations, triple, settings, finished) do
    infer(triple, Map.put(settings, finished, false)) ++ materializations
  end
end
