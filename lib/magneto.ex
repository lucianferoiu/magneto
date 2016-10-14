defmodule Magneto do

  defmacro __using__(_) do
    quote do
      require Magneto.Operations
      require Magneto.Operations.DDL
      import Magneto.Operations.DDL
      require Magneto.Operations.DML
      import Magneto.Operations.DML
      require Magneto.Operations.Query
      import Magneto.Operations.Query
    end
  end

end
