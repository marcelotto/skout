# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [
    # TODO: This should be an export from RDF.ex
    defvocab: 2
  ]
]
