defmodule MagnetoOpsDMLTest do
  use ExUnit.Case
  use Magneto
  doctest Magneto.Operations
  require Logger
  alias Magneto.Type


  defmodule SingleKeyModel do
    use Magneto.Model
    hash ssn: :number
    attributes name: :string, age: :number
  end

  defmodule CompositeKeyModel do
    use Magneto.Model
    hash grand_prix: :string
    range year: :number
    attributes winner: :string, fastest_lap: :string
  end

  setup_all do
    t1 = create SingleKeyModel
    # Logger.debug "Table desc: #{inspect t1}"
    t2 = create CompositeKeyModel
    # Logger.debug "Table desc: #{inspect t2}"

    on_exit(fn ->
      destroy CompositeKeyModel
      destroy SingleKeyModel
    end)
  end

  test "get item for key" do
    assert SingleKeyModel.__keys__ == [hash: {:ssn, :number}]
    get SingleKeyModel, for: 123
    assert CompositeKeyModel.__keys__ == [hash: {:grand_prix, :string}, range: {:year, :number}]
    get CompositeKeyModel, for: "Monaco", and: 2010
  end

  test "put values" do
    vals1 = %{ssn: 1, name: "Toto 1"}
    vals2 = %{grand_prix: "Hungaroring", year: 2010, winner: "Mark Webber"}
    assert %{} = put vals1, into: SingleKeyModel
    assert {:error, _} = put %{name: "Toto 2"}, into: SingleKeyModel
    assert %{} = put vals2, into: CompositeKeyModel
    assert {:error, _} = put %{grand_prix: "Silverstone"}, into: CompositeKeyModel
  end

  test "put value and check it" do
    put %{ssn: 2, name: "Toto 2"}, into: SingleKeyModel
    val = get SingleKeyModel, for: 2
    assert val.name == "Toto 2"
    put %{grand_prix: "SPA Francorchamps", year: 2010, fastest_lap: "Lewis Hamilton"}, into: CompositeKeyModel
    val = get CompositeKeyModel, for: "SPA Francorchamps", and: 2010
    assert val.fastest_lap == "Lewis Hamilton"
  end

  test "overwrite put values" do
    put %{ssn: 3, name: "Toto 3"}, into: SingleKeyModel
    val = get SingleKeyModel, for: 3
    assert val.name == "Toto 3"
    put %{ssn: 3, name: "Modified Toto 3"}, into: SingleKeyModel
    val = get SingleKeyModel, for: 3
    assert val.name == "Modified Toto 3"

    put %{grand_prix: "Nürburgring", year: 2010, winner: "Fernando Alonso"}, into: CompositeKeyModel
    val = get CompositeKeyModel, for: "Nürburgring", and: 2010
    assert val.fastest_lap == nil
    put %{grand_prix: "Nürburgring", year: 2010, fastest_lap: "Sebastian Vettel", winner: "Fernando Alonso"}, into: CompositeKeyModel
    val = get CompositeKeyModel, for: "Nürburgring", and: 2010
    assert val.fastest_lap == "Sebastian Vettel"
  end

  test "wrong number of keys in get" do
    assert SingleKeyModel.__keys__ == [hash: {:ssn, :number}]
    assert_raise(ArgumentError, fn ->
        get SingleKeyModel, with: 1, and: 3
    end)
    assert CompositeKeyModel.__keys__ == [hash: {:grand_prix, :string}, range: {:year, :number}]
    assert_raise(ArgumentError, fn ->
        get CompositeKeyModel, with: "Suzuka"
    end)
  end


end
