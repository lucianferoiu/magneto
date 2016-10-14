defmodule MagnetoOpsQueryTest do
  use ExUnit.Case
  use Magneto
  doctest Magneto.Operations
  require Logger



  defmodule GrandPrixModel do
    use Magneto.Model
    hash grand_prix: :string # like "Monaco"
    range year: :number
    attributes winner_driver: :string, best_lap_driver: :string, pole_position_driver: :string
    attribute laps: :number
    attribute all_time_winner: :string #most wins on this circuit

    index local: GPWinner, range: :all_time_winner, projection: :keys

  end

  setup_all do
    create GrandPrixModel

    # populate the table
    put %{grand_prix: "GP1", year: 2010, winner_driver: "Driver1", all_time_winner: "Driver2"}, into: GrandPrixModel
    put %{grand_prix: "GP2", year: 2010, winner_driver: "Driver2", all_time_winner: "Driver1"}, into: GrandPrixModel
    put %{grand_prix: "GP3", year: 2010, winner_driver: "Driver3", all_time_winner: "Driver3"}, into: GrandPrixModel
    put %{grand_prix: "GP1", year: 2011, winner_driver: "Driver2", all_time_winner: "Driver2"}, into: GrandPrixModel
    put %{grand_prix: "GP2", year: 2011, winner_driver: "Driver3", all_time_winner: "Driver1"}, into: GrandPrixModel
    put %{grand_prix: "GP3", year: 2011, winner_driver: "Driver1", all_time_winner: "Driver3"}, into: GrandPrixModel
    put %{grand_prix: "GP1", year: 2012, winner_driver: "Driver2", all_time_winner: "Driver2"}, into: GrandPrixModel
    put %{grand_prix: "GP2", year: 2012, winner_driver: "Driver1", all_time_winner: "Driver1"}, into: GrandPrixModel
    put %{grand_prix: "GP3", year: 2012, winner_driver: "Driver3", all_time_winner: "Driver3"}, into: GrandPrixModel

    on_exit(fn ->
      destroy GrandPrixModel
    end)
  end

  test "simple query" do
    vals = query GrandPrixModel, for: "GP1"
    Logger.debug "All values for GP1: #{inspect vals}"
  end

  test "simple scan" do
    vals = scan GrandPrixModel
    Logger.debug "All values in GrandPrixModel: #{inspect vals}"
    
    vals = scan GrandPrixModel, where: winner_driver == pole_position_driver and winner_driver == all_time_winner, limit: 100
    Logger.debug "All Grand Prix where the winner took all: #{inspect vals}"
  end

end
