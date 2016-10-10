defmodule Magneto.Model do
  require Logger
  alias Magneto.Type

  defmodule Metadata do
    defstruct [:storage, :keys, :attributes, :global_indexes, :local_indexes]
  end

  defmacro __using__(_) do
    target = __CALLER__.module
    # Logger.debug "Using #{__MODULE__} to inject into #{target}"

    default_namespace = Application.get_env(:magneto, :namespace) || "magneto"
    table_name = String.split(Atom.to_string(target), ".") |> List.last

    Module.put_attribute(target, :namespace, default_namespace)
    Module.put_attribute(target, :table_name, table_name)
    Module.register_attribute(target, :attributes, accumulate: true)
    Module.put_attribute(target, :keys, [hash: {:id, :number}]) # default pk

    quote do
      import Magneto.Model
      @before_compile unquote(__MODULE__)
    end
  end

  # -----

  defmacro __before_compile__(env) do
    # Logger.debug "#{env.module} -> __before_compile__"
    target = env.module
    namespace = Module.get_attribute(target, :namespace)
    table_name = Module.get_attribute(target, :table_name)
    Module.put_attribute(target, :canonical_table_name, "#{namespace}.#{table_name}")
    Module.eval_quoted __CALLER__, [
      Magneto.Model.__def_struct__(target),
      Magneto.Model.__def_helper_funcs__(target)
    ]
  end

  # -----

  defmacro namespace(custom_ns) when is_binary(custom_ns) do
    configured_ns = Module.get_attribute(__CALLER__.module, :namespace)
    actual_ns = "#{configured_ns}.#{custom_ns}"
    Module.put_attribute(__CALLER__.module, :namespace, actual_ns)
  end
  defmacro namespace(custom_ns, :override) when is_binary(custom_ns) do
    Module.put_attribute(__CALLER__.module, :namespace, custom_ns)
  end

  # define hash and range keys
  defmacro hash(decl) do
    quote bind_quoted: [decl: decl] do
      {name, type} = case decl do
        [{name, type}] -> {name, type}
        name when is_atom(name) -> {name, :string}
        name when is_binary(name) -> {String.to_atom(name), :string}
      end
      Magneto.Model.__attribute__(__MODULE__, name, type)
      Magneto.Model.__key__(__MODULE__, :hash, name, type)
    end
  end
  defmacro partition_key(decl), do: quote do: hash(unquote(decl))

  defmacro range(decl) do
    quote bind_quoted: [decl: decl] do
      {name, type} = case decl do
        [{name, type}] -> {name, type}
        name when is_atom(name) -> {name, :number}
        name when is_binary(name) -> {String.to_atom(name), :number}
      end
      Magneto.Model.__attribute__(__MODULE__, name, type)
      Magneto.Model.__key__(__MODULE__, :range, name, type)
    end
  end
  defmacro sort_key(decl), do: quote do: range(unquote(decl))

  # define an attribute
  defmacro attribute(decl) do
    quote bind_quoted: [decl: decl] do
      {name, type} = case decl do
        [{name, type}] -> {name, type}
        name when is_atom(name) -> {name, :string}
        name when is_binary(name) -> {String.to_atom(name), :string}
      end
      Magneto.Model.__attribute__(__MODULE__, name, type)
    end
  end

  defmacro attributes(decl) do
    {list_of_attrs, _} = Code.eval_quoted(decl)
    for attr <- list_of_attrs do
      quote do: attribute([unquote(attr)])
    end
  end

  # ----

  def __attribute__(mod, name, type) do
    existing_attributes = Module.get_attribute(mod, :attributes)
    if Keyword.has_key?(existing_attributes, name) do
      raise ArgumentError, "Duplicate attribute #{name}"
    end
    check_type!(type, name)
    Module.put_attribute(mod, :attributes, {name, type})
  end

  def __key__(mod, key_type, name, type) when key_type in [:hash, :range] do
    updated_keys =
      Module.get_attribute(mod, :keys)
        |> Keyword.delete(key_type)
        |> Keyword.put(key_type, {name, type})
        |> Enum.sort
    Module.put_attribute(mod, :keys, updated_keys)
  end

  def __def_struct__(mod) do
    canonical_table_name = Module.get_attribute(mod, :canonical_table_name)
    keys = Module.get_attribute(mod, :keys)
    attribs = Module.get_attribute(mod, :attributes)
    fields = attribs |> Enum.map(fn {name, type} -> {name, Type.default_value(type)} end)

    meta = %Metadata{ storage: canonical_table_name,
        keys: keys, attributes: attribs}
    fields = [__meta__: Macro.escape(Macro.escape(meta))] ++ fields # double-escape for the doubly-quoted

    # quote in quote because we eval_quoted the result of the function
    quote bind_quoted: [fields: fields] do
      quote do
        defstruct unquote(fields)
      end
    end
  end

  def __def_helper_funcs__(mod) do
    namespace = Module.get_attribute(mod, :namespace)
    canonical_table_name = Module.get_attribute(mod, :canonical_table_name)
    keys = Module.get_attribute(mod, :keys)
    attribs = Module.get_attribute(mod, :attributes)
    quote do
      def __namespace__, do: unquote(namespace)
      def __canonical_name__, do: unquote(canonical_table_name)
      def __keys__, do: unquote(keys)
      def __attributes__, do: unquote(attribs)
    end
  end


  # -----


  defp check_type!(type, name) do
    cond do
      type in [:number, :string, :boolean, :binary] ->
        {:native, type}
      type in [:date, :timestamp, :uuid, :any] ->
        {:custom, type}
      is_list(type) and length(type) == 1 ->
        [inner_type] = type
        {:composite, check_type!(inner_type, name)}
      is_map(type) ->
        {:composite, Enum.map(type, fn {n,t} -> check_type!(t, n) end) }
      is_atom(type) ->
        if Code.ensure_compiled?(type) and function_exported?(type, :type, 0) do
          {:composite, type}
        else
          raise ArgumentError, "invalid model #{inspect type} for attribute #{inspect name}"
        end
      true ->
        raise ArgumentError, "invalid type #{inspect type} for attribute #{inspect name}"
    end
  end


end
