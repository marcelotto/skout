defmodule Skout.YAML.Encoder do
  @moduledoc false

  alias Skout.{Document, Manifest, IriBuilder, Materialization}
  alias RDF.NS.{SKOS, RDFS}
  alias Skout.NS.DC
  alias RDF.{Graph, Description, IRI, Literal}

  @concept_scheme_description_blueprint [
    # Schema
    RDF.type(),
    RDFS.subClassOf(),
    # Lexical labels
    SKOS.prefLabel(),
    SKOS.altLabel(),
    SKOS.hiddenLabel(),
    SKOS.notation(),
    # Documentation
    DC.title(),
    DC.creator(),
    DC.created(),
    DC.modified(),
    SKOS.definition(),
    SKOS.example(),
    SKOS.scopeNote(),
    SKOS.changeNote(),
    SKOS.historyNote(),
    SKOS.note(),
    SKOS.editorialNote(),
    RDFS.isDefinedBy(),
    RDFS.seeAlso()
  ]

  @concept_description_blueprint [
    # Schema
    RDF.type(),
    RDFS.subClassOf(),
    # Lexical labels
    SKOS.prefLabel(),
    SKOS.altLabel(),
    SKOS.hiddenLabel(),
    SKOS.notation(),
    # Documentation
    SKOS.definition(),
    SKOS.example(),
    SKOS.scopeNote(),
    SKOS.changeNote(),
    SKOS.historyNote(),
    SKOS.note(),
    SKOS.editorialNote(),
    DC.creator(),
    DC.created(),
    DC.modified(),
    RDFS.isDefinedBy(),
    RDFS.seeAlso(),
    # Semantic relations
    SKOS.related(),
    SKOS.narrower(),
    # Mapping properties
    SKOS.exactMatch(),
    SKOS.closeMatch(),
    SKOS.narrowMatch(),
    SKOS.broadMatch(),
    SKOS.relatedMatch()
  ]

  @known_properties IriBuilder.known_properties()
                    |> Map.new(fn {property, iri} -> {iri, property} end)

  unless @known_properties
         |> Map.drop(@concept_description_blueprint ++ [DC.title()])
         |> Enum.empty?() do
    raise """
    The following known properties are missing in the concept description blueprint:
    - #{
      @known_properties
      |> Map.drop(@concept_description_blueprint)
      |> Enum.map(fn {property, _} -> to_string(property) end)
      |> Enum.join("\n- ")
    }
    """
  end

  @props_with_range_concept Materialization.semantic_relations() ++
                              Materialization.props_with_range_concept()

  @line_length 80

  def encode(document, opts \\ []) do
    {:ok,
     """
     #{preamble(document, opts) |> String.trim()}
     ---
     #{body(document, opts)}
     """}
  end

  def encode!(document, opts \\ []) do
    case encode(document, opts) do
      {:ok, yaml} -> yaml
      {:error, error} -> raise error
    end
  end

  def preamble(document, opts) do
    document.manifest
    |> Map.from_struct()
    |> Enum.reject(fn {key, value} -> is_nil(value) or key in [:materialization] end)
    |> Enum.map(fn
      {:concept_scheme, description} ->
        concept_scheme(document, description, opts)

      {key, value} ->
        """
        #{to_string(key)}: #{value}
        """
    end)
    |> Enum.join()
  end

  defp concept_scheme(_, false, _), do: ""

  defp concept_scheme(document, concept_scheme, opts) do
    description = concept_scheme_description(document, concept_scheme)

    if Enum.empty?(description) do
      """
      concept_scheme: #{concept_scheme}
      """
    else
      """
      concept_scheme:
        id: #{concept_scheme}
      """ <>
        Enum.map_join(@concept_scheme_description_blueprint, fn property ->
          statement(
            concept_scheme,
            property,
            description,
            document,
            1,
            nil,
            opts
            |> Keyword.put(:indent_style, :concept_scheme_description)
            |> Keyword.put(:property_term_style, :concept_scheme_description)
          )
        end)
    end
  end

  defp concept_scheme_description(document, id) do
    filtered_description(document, id, @concept_scheme_description_blueprint)
  end

  defp filtered_description(document, subject, filtered_properties) do
    document.skos
    |> Graph.get(subject, Description.new(subject))
    |> Enum.filter(fn {_, predicate, _} -> predicate in filtered_properties end)
    |> case do
      [] -> Description.new(subject)
      triples -> Description.new(subject, init: triples)
    end
  end

  def body(document, opts) do
    document
    |> Materialization.top_concepts()
    |> MapSet.new()
    |> concepts(document, 0, MapSet.new(), opts)
  end

  defp concepts(concepts, document, depth, visited, opts) do
    if MapSet.disjoint?(visited, concepts) do
      concepts
      |> Enum.map(fn concept -> concept(concept, document, depth, visited, opts) end)
      |> Enum.join(indentation(depth))
    else
      raise "concept scheme contains a circle through #{
              inspect(MapSet.intersection(concepts, visited) |> MapSet.to_list())
            }"
    end
  end

  defp concept(concept, document, depth, visited, opts) do
    description = Graph.description(document.skos, concept)

    concept_label(concept, description, document, opts) <>
      ":\n" <>
      Enum.map_join(@concept_description_blueprint, fn property ->
        statement(concept, property, description, document, depth, visited, opts)
      end)
  end

  defp concept_label(concept, %Document{} = document, opts) do
    if description = Graph.description(document.skos, concept) do
      concept_label(concept, description, document, opts)
    end
  end

  defp concept_label(concept, %Description{} = description, document, _opts) do
    label_type = Manifest.label_property(document.manifest)

    description
    |> Description.get(label_type)
    |> case do
      nil -> raise "Missing #{label_type} label for concept #{concept}"
      labels -> labels |> select_label() |> to_string()
    end
  end

  def select_label([label | _]), do: label

  defp statement(subject, property, description, document, depth, visited, opts) do
    if objects = Description.get(description, property) do
      do_statement(subject, property, objects, document, depth, visited, opts)
    else
      ""
    end
  end

  defp do_statement(
         concept,
         unquote(Macro.escape(SKOS.narrower())),
         narrower_concepts,
         document,
         depth,
         visited,
         opts
       ) do
    narrower_concepts
    |> MapSet.new()
    |> concepts(document, depth + 1, MapSet.put(visited, concept), opts)
    |> case do
      "" -> ""
      next_level -> indentation(depth + 1) <> next_level
    end
  end

  defp do_statement(_, unquote(Macro.escape(RDF.type())), objects, document, depth, _, opts) do
    filtered_objects = objects -- [RDF.iri(SKOS.Concept), RDF.iri(SKOS.ConceptScheme)]

    if not Enum.empty?(filtered_objects) do
      generic_statement(RDF.type(), filtered_objects, document, depth, opts)
    else
      ""
    end
  end

  defp do_statement(_, property, objects, document, depth, _, opts) do
    if property == Manifest.label_property(document.manifest) and
         Keyword.get(opts, :property_term_style) != :concept_scheme_description do
      generic_statement(property, objects -- [select_label(objects)], document, depth, opts)
    else
      generic_statement(property, objects, document, depth, opts)
    end
  end

  defp generic_statement(_, [], _, _, _), do: ""

  defp generic_statement(property, objects, document, depth, opts) do
    if key = Map.get(@known_properties, property) do
      indentation(depth + 1, Keyword.get(opts, :indent_style)) <>
        property(key, Keyword.get(opts, :property_term_style)) <>
        ":" <>
        (objects
         |> object_terms(property, document, opts)
         |> objects(depth)) <>
        "\n"
    else
      # unknown properties are simply ignored
      ""
    end
  end

  defp property(property_term, :concept_scheme_description), do: to_string(property_term)
  defp property(property_term, _), do: ":" <> to_string(property_term)

  defp object_terms(objects, property, document, opts) do
    objects
    |> Enum.map(fn object -> object_term(object, property, document, opts) end)
    |> Enum.reject(&is_nil/1)
  end

  defp object_term(%IRI{} = object, property, document, opts)
       when property in @props_with_range_concept do
    case object_term(object, nil, document, opts) do
      ":" <> term -> term
      other -> other
    end
  end

  defp object_term(%IRI{} = object, _, document, opts) do
    label = concept_label(object, document, opts)

    if label && to_string(object) == to_string(document.manifest.base_iri) <> label do
      ":#{label}"
    else
      "<#{object}>"
    end
  end

  defp object_term(%Literal{} = object, property, _, _)
       when property in @props_with_range_concept do
    raise "Literal used as object on property #{property} with skos:Concept range: #{object}"
  end

  defp object_term(%Literal{} = object, _, _document, _) do
    to_string(object)
  end

  defp object_term(%RDF.BlankNode{}, _, _, _), do: nil

  defp objects([object_term], _), do: " " <> object_term

  defp objects(object_terms, depth) do
    if objects_fit_on_line?(object_terms, depth) do
      " [" <>
        Enum.join(object_terms, ", ") <>
        "]"
    else
      "\n" <>
        indentation(depth + 2) <>
        Enum.join(object_terms, "\n" <> indentation(depth + 2))
    end
  end

  defp objects_fit_on_line?(objects, depth) do
    Enum.reduce(
      objects,
      depth |> indentation() |> String.length(),
      fn object, length ->
        length + String.length(object) + 2
      end
    ) <= @line_length
  end

  defp indentation(depth), do: indentation(depth, :default)
  defp indentation(0, _), do: ""
  defp indentation(depth, :concept_scheme_description), do: String.duplicate("  ", depth - 1)
  defp indentation(depth, _), do: String.duplicate("  ", depth - 1) <> "- "
end
