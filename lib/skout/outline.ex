defmodule Skout.Outline do
  defstruct [:manifest, :skos]

  alias Skout.{Manifest, Materialization}
  alias RDF.{IRI, Literal, Graph}

  def new(manifest) do
    with {:ok, manifest} <- Manifest.new(manifest) do
      {:ok,
       %__MODULE__{
         manifest: manifest,
         skos: Graph.new()
       }}
    end
  end

  def new!(manifest) do
    case new(manifest) do
      {:ok, outline} -> outline
      {:error, error} -> raise error
    end
  end

  def add(%__MODULE__{} = outline, triple) when is_tuple(triple) do
    if RDF.Triple.valid?(triple) do
      {:ok,
       add_to_graph(
         outline,
         Materialization.apply(triple, outline.manifest.materialization)
       )}
    else
      {:error, "invalid triple: #{inspect(triple)}"}
    end
  end

  def update_graph(%__MODULE__{} = outline, fun) do
    %__MODULE__{outline | skos: fun.(outline.skos)}
  end

  def add_to_graph(%__MODULE__{} = outline, data) do
    update_graph(outline, &Graph.add(&1, data))
  end
end
