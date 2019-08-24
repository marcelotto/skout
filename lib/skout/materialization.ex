defmodule Skout.Materialization do
  defmodule Settings do
    defstruct rdf_type: true,
              in_scheme: true,
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

  def infer(triple, manifest) do
    do_infer(triple, manifest.materialization, manifest)
  end

  defp do_infer(
         {subject, @broader, object} = triple,
         %{inverse_hierarchy: true} = settings,
         manifest
       ) do
    [{object, @narrower, subject}]
    |> continue(triple, :inverse_hierarchy, settings, manifest)
  end

  defp do_infer(
         {subject, @narrower, object} = triple,
         %{inverse_hierarchy: true} = settings,
         manifest
       ) do
    [{object, @broader, subject}]
    |> continue(triple, :inverse_hierarchy, settings, manifest)
  end

  defp do_infer(
         {subject, @related, object} = triple,
         %{inverse_related: true} = settings,
         manifest
       ) do
    [{object, @related, subject}]
    |> continue(triple, :inverse_related, settings, manifest)
  end

  defp do_infer({subject, predicate, object} = triple, %{rdf_type: true} = settings, manifest)
       when predicate in @semantic_relations do
    [
      {subject, RDF.type(), SKOS.Concept},
      {object, RDF.type(), SKOS.Concept}
    ]
    |> continue(triple, :rdf_type, settings, manifest)
  end

  defp do_infer({subject, predicate, _} = triple, %{rdf_type: true} = settings, manifest)
       when predicate in @props_with_domain_concept do
    [{subject, RDF.type(), SKOS.Concept}]
    |> continue(triple, :rdf_type, settings, manifest)
  end

  defp do_infer({_, predicate, object} = triple, %{rdf_type: true} = settings, manifest)
       when predicate in @props_with_range_concept do
    [{object, RDF.type(), SKOS.Concept}]
    |> continue(triple, :rdf_type, settings, manifest)
  end

  defp do_infer(
         {subject, predicate, object} = triple,
         %{in_scheme: true} = settings,
         %{concept_scheme: concept_scheme} = manifest
       )
       when predicate in @semantic_relations and concept_scheme not in [nil, false] do
    [
      {subject, SKOS.inScheme(), manifest.concept_scheme},
      {object, SKOS.inScheme(), manifest.concept_scheme}
    ]
    |> continue(triple, :in_scheme, settings, manifest)
  end

  defp do_infer(
         {subject, predicate, _} = triple,
         %{in_scheme: true} = settings,
         %{concept_scheme: concept_scheme} = manifest
       )
       when predicate in @props_with_domain_concept and concept_scheme not in [nil, false] do
    [{subject, SKOS.inScheme(), manifest.concept_scheme}]
    |> continue(triple, :in_scheme, settings, manifest)
  end

  defp do_infer(
         {_, predicate, object} = triple,
         %{in_scheme: true} = settings,
         %{concept_scheme: concept_scheme} = manifest
       )
       when predicate in @props_with_range_concept and concept_scheme not in [nil, false] do
    [{object, SKOS.inScheme(), manifest.concept_scheme}]
    |> continue(triple, :in_scheme, settings, manifest)
  end

  defp do_infer(triple, _, _), do: [triple]

  defp continue(materializations, triple, finished, settings, manifest) do
    do_infer(triple, Map.put(settings, finished, false), manifest) ++ materializations
  end
end
