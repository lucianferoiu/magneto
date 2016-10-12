defmodule Magneto do

  defmacro __using__(_) do
    quote do
      require Magneto.Operations
      import Magneto.Operations.DDL
      require Magneto.Operations.DML
      import Magneto.Operations.DML
    end
  end

end
