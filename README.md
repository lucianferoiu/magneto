# Magneto

**An *Elixir* DSL for Amazon DynamoDB**

*Etymology: the name hints to the [device](https://en.wikipedia.org/wiki/Magneto) that generates electric current, like the dynamo, not to Professor Xavier's archenemy *

## Installation

  1. Add `magneto` to your list of dependencies in `mix.exs`:

    When it will be available in [Hex](https://hex.pm/docs/publish), you'd do the customary:

    ```elixir
    def deps do
      [{:magneto, "~> 0.0.1"}]
    end
    ```

    But since we're not there yet and this is a work in progress,
    add it like this (and live with the consequences):

    ```elixir
    def deps do
      [{:magneto, github: "lucianferoiu/magneto", tag: "v0.0.1"}]
    end
    ```

  2. Ensure `magneto` is started before your application:

    ```elixir
    def application do
      [applications: [:magneto]]
    end
    ```



### Attribution

Some code inspired by the amazing [Ecto library](https://github.com/elixir-ecto/ecto) and by [ExAWS](https://github.com/CargoSense/ex_aws).

### License

```
Copyright 2016 Lucian Feroiu

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
