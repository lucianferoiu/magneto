defmodule Magneto.Utils do

  @moduledoc false

  @doc "Convert timestamp (or the current time) to ISO-formatted string"
  def timestamp_to_str do
    right_now = Timex.now
    timestamp_to_str(right_now)
  end
  def timestamp_to_str(nil), do: nil
  def timestamp_to_str(time) do
    case Timex.format(time, "{ISO:Extended}") do
      {:ok, timestamp} -> timestamp
      _ -> nil
    end
  end

  @doc "Convert a string to the corresponding timestamp (assuming ISO-formatted string)"
  def timestamp_from_str(time_str) when is_binary(time_str) do
    with {:ok, time} <- Timex.parse(time_str, "{ISO:Extended}"), do: time
  end

end
