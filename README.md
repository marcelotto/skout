# Skout

[![Travis](https://img.shields.io/travis/marcelotto/skout.svg?style=flat-square)](https://travis-ci.org/marcelotto/skout)
[![Hex.pm](https://img.shields.io/hexpm/v/skout.svg?style=flat-square)](https://hex.pm/packages/skout)


A terse, opinionated format for [SKOS] concept schemes as outlines in YAML.

If you're looking for a way to manage huge concept schemes this won't be the right tool for you. But if you want a developer-friendly and easy solution for writing small and simple SKOS concept schemes or laying out the foundation for a larger one, this might be what you're looking for: 

- easy to read, write and edit concept hierarchies
- auto-generated boilerplate statements about concepts


## Example

This Skout document:

```yaml
base: http://transport.data.gov.uk/def/vehicle-category/
concept_scheme:
  title: Vehicle Types
  creator: UK Department for Transport
  isDefinedBy: <http://www.dft.gov.uk/matrix/forms/definitions.aspx>
  seeAlso: <https://www.jenitennison.com/2009/11/22/creating-linked-data-part-iii-defining-concept-schemes.html>
iri_normalization: camelize  
---
- Pedal cycles
- All motor vehicles:
  - Two wheeled motor vehicles
  - Cars and taxis
  - Buses and coaches
  - Light vans
  - All HGV:
    - Rigid HGV:
      - HGVr2
      - HGVr3
      - HGVr4+
    - Articulated HGV:
      - HGVa3/4
      - HGVa5
      - HGVa6
```

produces these RDF statements:

```turtle
@prefix : <http://transport.data.gov.uk/def/vehicle-category/> .
@prefix dct: <http://purl.org/dc/terms/> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix skos: <http://www.w3.org/2004/02/skos/core#> .

:
    a skos:ConceptScheme ;
    dct:title "Vehicle Types" ;
    dct:creator "UK Department for Transport" ;
    rdfs:isDefinedBy <http://www.dft.gov.uk/matrix/forms/definitions.aspx> ;
    rdfs:seeAlso <https://www.jenitennison.com/2009/11/22/creating-linked-data-part-iii-defining-concept-schemes.html> ;
    skos:hasTopConcept :AllMotorVehicles, :PedalCycles .

:AllHGV
    a skos:Concept ;
    skos:broader :AllMotorVehicles ;
    skos:inScheme : ;
    skos:narrower :ArticulatedHGV, :RigidHGV ;
    skos:prefLabel "All HGV" .

:AllMotorVehicles
    a skos:Concept ;
    skos:inScheme : ;
    skos:narrower :AllHGV, :BusesAndCoaches, :CarsAndTaxis, :LightVans, :TwoWheeledMotorVehicles ;
    skos:prefLabel "All motor vehicles" ;
    skos:topConceptOf : .

:ArticulatedHGV
    a skos:Concept ;
    skos:broader :AllHGV ;
    skos:inScheme : ;
    skos:narrower :HGVa34, :HGVa5, :HGVa6 ;
    skos:prefLabel "Articulated HGV" .

:BusesAndCoaches
    a skos:Concept ;
    skos:broader :AllMotorVehicles ;
    skos:inScheme : ;
    skos:prefLabel "Buses and coaches" .

:CarsAndTaxis
    a skos:Concept ;
    skos:broader :AllMotorVehicles ;
    skos:inScheme : ;
    skos:prefLabel "Cars and taxis" .

:HGVa34
    a skos:Concept ;
    skos:broader :ArticulatedHGV ;
    skos:inScheme : ;
    skos:prefLabel "HGVa3/4" .

:HGVa5
    a skos:Concept ;
    skos:broader :ArticulatedHGV ;
    skos:inScheme : ;
    skos:prefLabel "HGVa5" .

:HGVa6
    a skos:Concept ;
    skos:broader :ArticulatedHGV ;
    skos:inScheme : ;
    skos:prefLabel "HGVa6" .

:HGVr2
    a skos:Concept ;
    skos:broader :RigidHGV ;
    skos:inScheme : ;
    skos:prefLabel "HGVr2" .

:HGVr3
    a skos:Concept ;
    skos:broader :RigidHGV ;
    skos:inScheme : ;
    skos:prefLabel "HGVr3" .

:HGVr4
    a skos:Concept ;
    skos:broader :RigidHGV ;
    skos:inScheme : ;
    skos:prefLabel "HGVr4+" .

:LightVans
    a skos:Concept ;
    skos:broader :AllMotorVehicles ;
    skos:inScheme : ;
    skos:prefLabel "Light vans" .

:PedalCycles
    a skos:Concept ;
    skos:inScheme : ;
    skos:prefLabel "Pedal cycles" ;
    skos:topConceptOf : .

:RigidHGV
    a skos:Concept ;
    skos:broader :AllHGV ;
    skos:inScheme : ;
    skos:narrower :HGVr2, :HGVr3, :HGVr4 ;
    skos:prefLabel "Rigid HGV" .

:TwoWheeledMotorVehicles
    a skos:Concept ;
    skos:broader :AllMotorVehicles ;
    skos:inScheme : ;
    skos:prefLabel "Two wheeled motor vehicles" .
```



## Installation

Skout is written in Elixir. This means you'll have to have [Elixir installed](https://elixir-lang.org/install.html). With that you can install the CLI as a so called escript with the following command: 

```sh
$ mix escript.install github marcelotto/skout
``` 

After installation, the escript can be invoked as

```sh
$ ~/.mix/escripts/skout
```

For convenience, consider adding the `~/.mix/escripts` directory to your `PATH` environment variable.

If you intend to use Skout just as a dependency of your project, you can just add the Hex package as usual to your list of dependencies in `mix.exs` and fetch it with `mix deps.get`:

```elixir
def deps do
  [
    {:skout, "~> 0.1"}
  ]
end
```

The API documentation for Skout can be found [here](https://hexdocs.pm/skout).



## Introduction

The main idea in Skout is to write out your concept hierarchy of narrower concepts in a YAML outline and make various assumptions for how to translate these outlines into proper RDF:

1. All IRIs of the concepts belong to the same base IRI namespace.
2. All IRIs of the concepts are a (configurable) normalized form of the `skos:prefLabel` appended to the base IRI namespace.
3. The IRI of the concept scheme is if not otherwise specified the base IRI.
4. All concepts belong to the same concept scheme in terms of `skos:inScheme`.
5. Every concept without a `skos:broader` concept is a top concept of the concept scheme.


### Skout documents

A Skout document is a normal YAML document. It consists of an outline of the concept hierarchy as a nested map and an optional preamble as a YAML frontmatter document. The preamble contains some basic configurations and a description of the concept scheme.


### Concepts

As you can see in the example above the concept hierarchy is simply a list of nested maps with the narrower hierarchy of the top concepts. The concepts are written by using their `skos:preflabel`. 

So, how are the IRIs for the concepts created? As stated in the first two assumptions above, the IRIs are concatenations of the base IRI and a normalization of the `skos:prefLabel`. The base IRI is the only required parameter for the translation to RDF and must be preferably provided in the preamble with the `base_iri` field (or its alias `base`) or directly given to the CLI (or the respective Elixir functions). The `skos:prefLabel` used in the concept hierarchy is then normalized by applying a normalization method, which can be configured with the `iri_normalization` field in the preamble. Currently, there are two methods available: `camelize` and `underscore`. If not specified, it defaults to `camelize`. If you are calling the Elixir functions, you can also pass a custom normalization function. 

For each concept in the concept hierarchy an `rdf:type skos:Concept` statement and a label statement is produced in the RDF translation. The property used for the label statement can be defined with the `label_type` field in the preamble. 
Possible values are `prefLabel`, which will use `skos:prefLabel` for the label statements and is the default, or `notation` for the `skos:notation` property. By default a plain string is used for the object of the label statement, but you can configure a language tag which should be used with the `default_language` field in the preamble.

The nesting of the concepts will be translated to both `skos:narrower` and `skos:broader` statements accordingly. 

So, all in all, this Skout document:


```yaml
base_iri: http://example.com/
default_language: en
iri_normalization: underscore
concept_scheme: false
---
Foo:
- Bar baz
```

would be translated to these RDF statements:

```turtle
@prefix : <http://example.com/> .
@prefix skos: <http://www.w3.org/2004/02/skos/core#> .

:bar_baz
    a skos:Concept ;
    skos:broader :foo ;
    skos:prefLabel "Bar baz"@en .

:foo
    a skos:Concept ;
    skos:narrower :bar_baz ;
    skos:prefLabel "Foo"@en .
```

### Concept descriptions

It is possible to add statements about the concepts with a limited set of properties. This can be done by adding them as key value pairs under the subject concept using a known term for the properties prefixed with a colon. This is the list of known properties and the terms that must be used for them:

| Property                | Term              |
| :---------------------- | :---------------- |
| `skos:related`          | `related`         |
| `skos:prefLabel`        | `prefLabel`       |
| `skos:altLabel`         | `altLabel`        |
| `skos:hiddenLabel`      | `hiddenLabel`     |
| `skos:notation`         | `notation`        |
| `skos:definition`       | `definition`      |
| `skos:example`          | `example`         |
| `skos:note`             | `note`            |
| `skos:scopeNote`        | `scopeNote`       |
| `skos:changeNote`       | `changeNote`      |
| `skos:historyNote`      | `historyNote`     |
| `skos:editorialNote`    | `editorialNote`   |
| `skos:relatedMatch`     | `relatedMatch`    |
| `skos:exactMatch`       | `exactMatch`      |
| `skos:closeMatch`       | `closeMatch`      |
| `skos:broadMatch`       | `broadMatch`      |
| `skos:narrowMatch`      | `narrowMatch`     |
| `rdf:type`              | `a`               |
| `rdfs:subClassOf`       | `subClassOf`      |
| `rdfs:isDefinedBy`      | `isDefinedBy`     |
| `rdfs:seeAlso`          | `seeAlso`         |
| `dct:title`             | `title`           |
| `dct:creator`           | `creator`         |
| `dct:created`           | `created`         |
| `dct:modified`          | `modified`        |

For the objects of statement the following you can use all of YAMLs natively supported literal forms which will be mapped to the respective RDF literals. IRIs can be written in angle brackets. If the IRI belongs to the base IRI namespace, you can also leave the base IRI part away and just write a colon instead. For properties with the `rdfs:range skos:Concept` you can even leave the colon away and just write the label of the concept, just as you do it in the narrower hierarchy. Multiple objects to the same property can be written by using any of the forms YAML supports for lists.

Here's an example using all of the mentioned features:

```yaml
base_iri: http://example.com/
---
Foo:
- :related: Bar
- :a: [:Bar, <http://example.com/Type>]
- :altLabel: [false, true, 3.14, 42]
- :seeAlso:
  - <http://example.com/another/Foo>
  - <http://example.com/other/Foo>
- Baz:
```

This will be translated to these RDF statements:

```turtle
@prefix : <http://example.com/> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix skos: <http://www.w3.org/2004/02/skos/core#> .

:Bar
    a skos:Concept ;
    skos:related :Foo .

:Baz
    a skos:Concept ;
    skos:broader :Foo ;
    skos:prefLabel "Baz" .

:Foo
    a :Bar, <http://example.org/other/Type>, skos:Concept ;
    rdfs:seeAlso <http://example.com/another/Foo>, <http://example.com/other/Foo> ;
    skos:altLabel true, 3.14, 42 ;
    skos:narrower :Baz ;
    skos:prefLabel "Foo" ;
    skos:related :Bar .
```

As you can see, this goes against the original purpose of providing a good overview over the concept scheme. I strongly recommend to use this very sparsely. It's planned to support different kinds of blocks in a Skout documents in upcoming versions for the different parts of a SKOS concept scheme, so they can be kept clean and separated.


### Concept scheme

In the previous examples we disabled the production of the concept scheme by setting the `concept_scheme` field in the preamble to `false`. If you don't disable it like this and don't set it to a specific IRI to be used for the concept scheme, Skout will assume it's the same IRI as the base IRI and produce statements linking all concepts with the `skos:inScheme` property to the concept scheme. It will also assume all concepts without a `skos:broader` concept to be top-level concepts and produce respective `skos:hasTopConcept` and `skos:topConceptOf` statements.

You can also make statements about the concept scheme with all of above mentioned known properties by putting them in a map as the `concept_scheme` value. As opposed to the descriptions in the concept hierarchy, you don't have to use the leading colon here. You can define a different IRI than the base IRI in this description form of the `concept_scheme` by using the `id` field.

Let's enable the concept scheme in the example above and add a few statements:

```yaml
base_iri: http://example.com/
concept_scheme:
  id: <http://example.com/foo/ConceptScheme>
  title: Example concept scheme
  creator: Marcel
---
Foo:
- Bar baz
``` 

This will be translated now to these RDF statements:

```turtle
@prefix : <http://example.com/> .
@prefix dct: <http://purl.org/dc/terms/> .
@prefix skos: <http://www.w3.org/2004/02/skos/core#> .

:BarBaz
    a skos:Concept ;
    skos:broader :Foo ;
    skos:inScheme <http://example.com/foo/ConceptScheme> ;
    skos:prefLabel "Bar baz" .

:Foo
    a skos:Concept ;
    skos:inScheme <http://example.com/foo/ConceptScheme> ;
    skos:narrower :BarBaz ;
    skos:prefLabel "Foo" ;
    skos:topConceptOf <http://example.com/foo/ConceptScheme> .

<http://example.com/foo/ConceptScheme>
    a skos:ConceptScheme ;
    dct:title "Example concept scheme" ;
    dct:creator "Marcel" ;
    skos:hasTopConcept :Foo .
```


### CLI

If you've followed the installation instructions above for the escript and added the escript directory to your `PATH`, you can use the `skout` command to translate Skout documents to all the RDF serializations supported by [RDF.ex](https://github.com/marcelotto/rdf-ex) (for now Turtle, N-Triples, N-Quads and JSON-LD) and vice versa.

```sh
$ skout input.yml output.ttl
$ skout input.nt output.yml
```

Run `skout --help` to see all available options.



## Contributing

see [CONTRIBUTING](CONTRIBUTING.md) for details.


## Consulting and Partnership

If you need help with your Elixir and Linked Data projects, just contact <info@cokron.com> or visit <https://www.cokron.com/kontakt>


## License and Copyright

(c) 2019 Marcel Otto. MIT Licensed, see [LICENSE](LICENSE.md) for details.


[SKOS]:  http://www.w3.org/TR/skos-reference
