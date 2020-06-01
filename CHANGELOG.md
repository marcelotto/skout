# Change Log

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/) and
[Keep a CHANGELOG](http://keepachangelog.com).


## v0.1.3 - 2020-06-02

- Upgrade to RDF.ex 0.8


[Compare v0.1.2...v0.1.3](https://github.com/marcelotto/skout/compare/v0.1.2...v0.1.3)



## v0.1.2 - 2019-12-16

- Upgrade to RDF.ex 0.7

[Compare v0.1.1...v0.1.2](https://github.com/marcelotto/skout/compare/v0.1.1...v0.1.2)



## v0.1.1 - 2019-09-12

### Added 

- new Document configuration `label_type` which can be set in the preamble
  with the SKOS property to be used for producing the label statements;
  for now only `:prefLabel` (the default) and `notation` are allowed


### Changed

- It's possible now to use the property which is used in the production of the
  label statements for the terms in the hierarchy (before always `skos:prefLabel`,   
  but now also `skos:notation`) in the term descriptions to specify further labels 
  of the resp. type, but beware that during simply the first one is selected as
  the one to be used in the hierarchy and since the objects are unordered this
  selection is non-deterministic.
- all types of SKOS labels are now supported for concept schemes; 
  previously `skos:prefLabel` wasn't 


[Compare v0.1.0...v0.1.1](https://github.com/marcelotto/skout/compare/v0.1.0...v0.1.1)



## v0.1.0 - 2019-09-09

Initial release
