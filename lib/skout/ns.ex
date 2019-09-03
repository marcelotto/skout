defmodule Skout.NS do
  use RDF.Vocabulary.Namespace

  @vocabdoc """
  The Dublin Core Metadata Terms vocabulary.

  See <http://purl.org/dc/terms/>
  """
  defvocab DC,
    base_iri: "http://purl.org/dc/terms/",
    file: "dct.nt",
    alias: [
      ISO639_2: "ISO639-2",
      ISO639_3: "ISO639-3"
    ],
    case_violations: :fail
end
