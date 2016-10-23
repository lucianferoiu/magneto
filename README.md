# Magneto

**An Elixir DSL for Amazon DynamoDB**

Etymology: the name hints to the [device](https://en.wikipedia.org/wiki/Magneto) that like the dynamo, generates electric current - not to Professor Xavier's archenemy.

**A word of caution:** the library is still very much a work in progress; you can toy with it, help me
extend it, but you shouldn't (yet!) use it for actual work but at your own peril.

## Installation

  1. Add `magneto` to your list of dependencies in `mix.exs`:

    Using it as a hex [dependency](https://hex.pm/packages/magneto), you'd add the customary:

    ```elixir
    def deps do
      [{:magneto, "~> 0.1.2"}]
    end
    ```

  2. Ensure `magneto` is started before your application:

    ```elixir
    def application do
      [applications: [:magneto]]
    end
    ```
  3. Change the AWS configuration as needed, with keys and region specifications to suit
  your DynamoDB usage.

  4. [optional] Install the run the local DynamoDB simulator
  (more info [here](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html))

---

## Usage

The rationale behind this library is to provide a declarative and close to natural language way to work with DynamoDB, and conveniently abstract away the heavily-verbose JSON interaction with the data store.
To some extent, this is already accomplished by the [ExAws](https://github.com/CargoSense/ex_aws), upon which this DSL relies. But the aim is to take the matters further and bring forth the underlying
concepts of DynamoDB and make them explicit and first-class citizens.

The list of features and concepts in DynamoDB is pretty terse (compared to a classical RDBMS, for
example); therefore the resulting DSL syntax is largely fixed, though it strives to be as
natural as possible.


### DDL

Describing a model (mapped to one DynamoDB table) should be straight-forward:

```elixir
defmodule GrandPrixModel do
  use Magneto.Model
  hash grand_prix: :string #like "Silverstone", "Suzuka" or "Monaco"
  range year: :number

  attributes winner_driver: :string, best_lap_driver: :string,
      pole_position_driver: :string
  attribute laps: :number
  attribute all_time_winner: :string #most wins on this circuit

  index local: GPWinner, range: :all_time_winner, projection: :keys

end
```

#### Model Definition
Simply define a module and `use Magneto.Model`.

#### Primary keys
Since the keys specification for DynamoDB is to have either one (hash) key or a composite of two keys (hash and range), declare them as such: `hash key_name: :key_type` and (optionally) `range key_name: :key_type`.
Since the documentation uses the terms *hash* and *partition key* interchangeably,
as well as *range* and *sort key* respectively, one can use those synonyms: `partition_key key_name: :key_type` and `sort_key key_name: :key_type`.

#### Attributes
The attributes declaration follows the same pattern observed above `att_name: :type`. One can specify attributes one by one (`attribute att_name...`) or as a list (`attributes att_1: :type1, att_2: :type2 ...`).

All the attributes and keys end up forming a `struct` so they can be accessed using the
dot notation `model.att_name`.

#### Data Types
From the storage perspective, the values of the attributes are all booleans, numbers, strings, *Base64*-encoded binaries or sets of them. We wanted to extend this list of native types with
some common custom ones: dates, timestamps, UUIDs (commonly-used as artificial PKs), as well as
to make transparent the use of embedded models.

Therefore, the list of types allowed for keys and attributes alike is `:boolean`,`:number`,`:string`,`:binary`,`:date`,`:timestamp`, `:uuid` `EmbeddedModel` and their list-form (`[:string]`, `[:date]`, etc).

The library is responsible for the conversion to and from the custom data types.

#### Indexes

There are *global* and *local* indexes:

`index local: IndexName, range: :range_attribute, projection: [:attributes, :to, :include]`

The range attribute is mandatory and must be one of the attributes defined above, as per the DynamoDB specification. The projected attributes must be also already defined. One could use the shortcut
to only project the index keys `... projection: :keys` or all the attributes `... projection: :all`.

The *global* index mandates that both hash and range keys be specified:

`index global: GlobalIndexName, hash: :att_hash, range: :att_range,
  projection: [:attributes, :to, :include]`

#### DDL Operations
Creating and deleting tables (permanent DynamoDB operations) is straight-forward:
```elixir
...
use Magneto
alias My.Magneto.Model

create Model
description = describe Model
destroy Model
```

### DML

The *CRUD* operations are simple because the storage model is simple:

#### Create and Update
There is really no distinction between creating a new item or updating an existing one (eventual consistency topics aside). The map of values to be inserted needs to include the keys too.
```elixir
...
use Magneto
alias My.Magneto.Model

put %{hash_key: uid, attribute1: att1_value}, into: Model
```

#### Reading
One needs to be aware of the one-key or composite-key structure of the model, because reading an
item must specify all the keys for the item:
```elixir
...
use Magneto
alias My.Magneto.SingleKeyModel
alias My.Magneto.CompositeKeyModel

v1 = get SingleKeyModel, for: uid
uid = v1.hash
IO.puts "attribute 1: #{v1.attribute1}"

v2 = get CompositeKeyModel, for: hash_value, and: range_value
hv = v2.hash
rv = v2.range
IO.puts "Retrieved vales for #{inspect v2.keys}: #{inspect v2}"
```
The `for:` keyword may be substituted with `hash:` or `with:`, depending on which phrasing sounds
better in English.

### Queries and Scans

This is largely *work-in-progress*, but the gist of usage should be:
```elixir
...
use Magneto
alias My.Formula1.Stats.GrandPrixModel

triple_crowns = scan GrandPrixModel, where: winner_driver == pole_position_driver
    and winner_driver == fastest_lap_driver, limit: 10

all_years_on_Monza = query GrandPrixModel, for: "Monza"

```


### Other concepts

#### Namespaces

The concept of namespace is artificial - it basically uses a prefix for the names of the tables
and indexes. It can be useful when one wants to delimit tables into sub-systems or when one has
many deployment environments (such as development, test and production) using the same AWS account
and wants to keep their data separate (obviously).

The root namespace is declared globally in the configuration:
```elixir
config :magneto,
  namespace: "local"
```
Inside a model, one can extend it:
```elixir
defmodule GrandPrixModel do
  use Magneto.Model
  namespace "analytics" # full name of the table: local.analytics.GrandPrixModel
  ...
```
or even override it altogether `namespace "global", :override`

#### Throughput
The read and write capacity is specified at the model level as
`throughput read: <number>, write: <number>`

Also, the global indexes support a similar keyword: `... projection: :keys, throughput: [<number>, <number>]`

---


## Roadmap

Unfinished features:
* pretty much all of them, for the moment :-S

Features to be added:
* Embedded models
* Two-phase commit emulation using static tables in DynamoDB

### Attribution

Some code inspired by the amazing [Ecto](https://github.com/elixir-ecto/ecto) library and the whole scaffolding gratefully relies on the wonderful [ExAws](https://github.com/CargoSense/ex_aws).

### License

```
Copyright (c) 2016 Lucian Feroiu

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
