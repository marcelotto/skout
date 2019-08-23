defmodule Skout.IriBuilder do
  alias Skout.Manifest
  alias RDF.IRI

  def from_label(%IRI{} = iri, _), do: iri

  def from_label(label, %Manifest{} = manifest) do
    from_label(label, manifest.base_iri, manifest.iri_normalization)
  end

  def from_label(label, base_iri, iri_normalization) when is_binary(label) do
    IRI.merge(base_iri, normalize_label(iri_normalization, label))
  end

  defp normalize_label(:camelize, label), do: camelize(label)
  defp normalize_label(:underscore, label), do: underscore(label)

  def underscore(word) when is_binary(word) do
    word
    |> String.replace(~r/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1_\\2")
    |> String.replace(~r/[-\s]/, "_")
    |> String.replace(~r/[#]/, "")
    |> String.downcase()
  end

  def camelize(word) do
    case Regex.split(~r/(?:^|[-_])|(?=[A-Z])|[\s#]/, word)
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
end
