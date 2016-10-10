defmodule MagnetoModelTest do
  use ExUnit.Case
  doctest Magneto.Model
  require Logger

  test "empty model - default properties" do
    defmodule EmptyModel do
      use Magneto.Model
    end
    ns = Application.get_env(:magneto, :namespace) || "magneto"
    assert EmptyModel.__namespace__ == ns
    assert EmptyModel.__keys__ == [hash: {:id, :number}]
    assert EmptyModel.__canonical_name__ == "#{ns}.EmptyModel"
  end

  test "custom namespace" do
    ns = Application.get_env(:magneto, :namespace) || "magneto"
    defmodule CustomNSModel do
      use Magneto.Model
      namespace "custom"
    end
    assert CustomNSModel.__namespace__ == "#{ns}.custom"
    assert CustomNSModel.__canonical_name__ == "#{ns}.custom.CustomNSModel"

    defmodule OverrideNSModel do
      use Magneto.Model
      namespace "custom", :override
    end
    assert OverrideNSModel.__namespace__ == "custom"
    assert OverrideNSModel.__canonical_name__ == "custom.OverrideNSModel"
  end

  test "single (hash) key" do
    defmodule HashKeyModel do
      use Magneto.Model
      hash username: :string
    end
    assert HashKeyModel.__keys__ == [hash: {:username, :string}]

    defmodule HashKeyAsStrModel do
      use Magneto.Model
      partition_key "email"
    end
    assert HashKeyAsStrModel.__keys__ == [hash: {:email, :string}]
  end

  test "with range key" do
    defmodule RangeKeyModel do
      use Magneto.Model
      range login: :timestamp #order doesn't matter
      hash username: :string
    end
    assert RangeKeyModel.__keys__ == [hash: {:username, :string}, range: {:login, :timestamp}]

    defmodule SortKeyModel do
      use Magneto.Model
      partition_key "GrandPrix"
      sort_key :finishing_place
    end
    assert SortKeyModel.__keys__ == [hash: {:GrandPrix, :string}, range: {:finishing_place, :number}]
  end


  test "simple attributes" do
    defmodule SimpleAttsModel do
      use Magneto.Model
      attribute age: :number
      attributes name: :string, email: :string, enabled: :boolean
      attribute last_login: :timestamp
    end

    atts = SimpleAttsModel.__attributes__
    for att <- [name: :string, email: :string, enabled: :boolean, age: :number, last_login: :timestamp] do
      assert Enum.member?(atts,att) == true
    end
  end

  defmodule StructModel do # needs to be declared outside the macro test because it won't expand the defstruct otherwise
    use Magneto.Model      # (!) actually, this may indicate a mistake in the macro expansion in Magneto.Model
    hash ssn: :number      # ... but TODO later
    attribute age: :number
    attributes name: :string, email: :string, enabled: :boolean
    attribute last_login: :timestamp
  end

  test "as struct" do
    instance = %StructModel{age: 12}
    assert instance.age == 12
    assert instance.name == "" #default value for strings
    assert instance.enabled == true #default value for booleans
    assert instance.__meta__.keys == [hash: {:ssn, :number}]
    assert instance.ssn == 0 #key as attribute
  end

  test "metadata struct" do

  end


end
