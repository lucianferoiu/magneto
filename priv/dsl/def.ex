defmodule User do
  use Magneto.Model

  namespace "local" # optional, defaults to magneto: :namespace config

  hash uuid:, :string               # partition uuid: :string
  range timestamp: :string         # sort timestamp: :string

  attributes name: :string, email: :string, age: :number, enabled: :boolean,
     roles: [:string], address: Address, avatars: [Avatar], properties: :map
  attribute mecs: [:map]

  throughput read: 3, write: 1   # throughput 3, 1

  index local: UserByEmail, sort: :email, attributes: [:name]
  index global: UsersOfAge, hash: :name, range: :age, attributes: [:email, :properties], throughput: [read: 2, write: 1]


end
