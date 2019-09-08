defmodule Skout.IriBuilder do
  @moduledoc false

  alias Skout.Manifest
  alias Skout.NS.DC
  alias RDF.NS.{SKOS, RDFS}
  alias RDF.IRI

  @known_properties (Skout.Helper.properties(SKOS) --
                       [
                         :prefLabel,
                         :broader,
                         :narrowerTransitive,
                         :broaderTransitive,
                         :semanticRelation,
                         :inScheme,
                         :hasTopConcept,
                         :topConceptOf
                       ])
                    |> Enum.map(fn property -> {property, apply(SKOS, property, [])} end)
                    |> Map.new()
                    |> Map.merge(%{
                      a: RDF.type(),
                      subClassOf: RDFS.subClassOf(),
                      isDefinedBy: RDFS.isDefinedBy(),
                      seeAlso: RDFS.seeAlso(),
                      title: DC.title(),
                      creator: DC.creator(),
                      created: DC.created(),
                      modified: DC.modified()
                    })
  def known_properties(), do: @known_properties

  def from_label(%IRI{} = iri, _), do: iri

  def from_label(label, %Manifest{} = manifest) do
    from_label(label, manifest.base_iri, manifest.iri_normalization)
  end

  def from_label(label, base_iri, iri_normalization) when is_binary(label) do
    RDF.iri(to_string(base_iri) <> normalize_label(iri_normalization, label))
  end

  defp normalize_label(:camelize, label), do: camelize(label)
  defp normalize_label(:underscore, label), do: underscore(label)
  defp normalize_label(fun, label) when is_function(fun), do: fun.(label)

  def underscore(word) when is_binary(word) do
    word
    |> String.replace(~r/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
    |> String.replace(~r/[-\+\s\/]/, "_")
    |> String.replace(~r/[#]/, "")
    |> String.downcase()
  end

  def camelize(word) do
    case Regex.split(~r/(?:^|[-_])|(?=[A-Z])|[\s#\/\+]/, word)
         |> Enum.filter(&(&1 != "")) do
      [first | words] ->
        [first | camelize_list(words)]
        |> Enum.join()
    end
  end

  defp camelize_list([]), do: []

  defp camelize_list([h | tail]) do
    [String.capitalize(h)] ++ camelize_list(tail)
  end

  def predicate(%IRI{} = iri, _), do: {:ok, iri}

  Enum.each(@known_properties, fn {property, iri} ->
    def predicate(unquote(to_string(property)), _),
      do: {:ok, unquote(Macro.escape(iri))}
  end)

  def predicate(term, %Manifest{} = _manifest) do
    {:error, "Unknown property '#{term}'"}
  end
end
