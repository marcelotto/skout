defmodule Skout.Outline do
  defstruct [:manifest, :skos]

  alias Skout.{Manifest, Materialization}
  alias RDF.Graph

  def new(manifest) do
    %__MODULE__{
      manifest: Manifest.new(manifest),
      skos: Graph.new()
    }
  end

  def add(%__MODULE__{} = outline, triple) when is_tuple(triple) do
    with {:ok, triple} <- coerce_triple(triple, outline.manifest) do
      {:ok,
       add_to_graph(
         outline,
         Materialization.apply(triple, outline.manifest.materialization)
       )}
    end
  end

  defp coerce_triple({subject, predicate, object}, manifest) do
    {:ok,
     {
       Manifest.term_to_iri(subject, manifest),
       Manifest.predicate_to_iri(predicate, manifest),
       Manifest.term_to_iri(object, manifest)
     }}
  end

  def update_graph(%__MODULE__{} = outline, fun) do
    %__MODULE__{outline | skos: fun.(outline.skos)}
  end

  def add_to_graph(%__MODULE__{} = outline, data) do
    update_graph(outline, &Graph.add(&1, data))
  end
end
