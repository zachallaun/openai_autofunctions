defmodule Autofunctions do
  @moduledoc """
  TODO
  """

  defmacro __using__(_) do
    quote do
      @after_verify Autofunctions
    end
  end

  @doc false
  def __after_verify__(module) do
    specs = module |> Code.Typespec.fetch_specs() |> normalize_specs()
    docs = module |> Code.fetch_docs() |> normalize_docs()

    functions =
      for {{name, arity}, params} <- specs_to_schemas(specs) do
        %{
          name: "#{arity}__#{name}",
          description: docs[{name, arity}],
          parameters: params
        }
      end

    :persistent_term.put({__MODULE__, module, :functions}, functions)
    :persistent_term.put({__MODULE__, module, :specs}, specs)

    :ok
  end

  @doc """
  Get the generated OpenAI function specs for the given model.
  """
  def get_functions(module) do
    :persistent_term.get({__MODULE__, module, :functions}, [])
  end

  @doc """
  Get the MFA for the requested function call.
  """
  def get_call(module, %{name: name, arguments: args}) do
    specs = :persistent_term.get({__MODULE__, module, :specs}, %{})

    # Turn the ARITY__NAME formatted function name into {:name, arity}
    [arity, name] = String.split(name, "__", parts: 2)
    {fun_name, _} = fun_arity = {String.to_existing_atom(name), String.to_integer(arity)}

    # Decode and order the args
    {params, _return} = specs[fun_arity]
    args = Jason.decode!(args, keys: :atoms!)
    args = for {name, _} <- params, do: Map.fetch!(args, name)

    {module, fun_name, args}
  end

  defp specs_to_schemas(specs) do
    for {fun_arity, _} = spec <- specs, into: %{} do
      {fun_arity, spec_to_schema_params(spec)}
    end
  end

  defp spec_to_schema_params({_fun_arity, {args, _return}}) do
    %{
      type: "object",
      properties: args_to_schema_properties(args),
      required: Keyword.keys(args)
    }
  end

  defp args_to_schema_properties(args) do
    for {name, type} <- args, into: %{} do
      {name, type_to_schema(type)}
    end
  end

  defp type_to_schema(:binary) do
    %{type: "string"}
  end

  defp type_to_schema(:pos_integer) do
    %{type: "integer", minimum: 1}
  end

  defp normalize_specs({:ok, specs}) do
    for {fun_arity, [{:type, _, :fun, [args, return]} | _]} <- specs,
        {:type, _, :product, args} = args,
        into: %{} do
      {fun_arity, {normalize_args(args), normalize_type(return)}}
    end
  end

  defp normalize_docs({:docs_v1, _, :elixir, _, _, _, docs}) do
    for {{:function, name, arity}, _, _, %{"en" => doc}, _} <- docs, into: %{} do
      {{name, arity}, String.trim(doc)}
    end
  end

  defp normalize_args(args) do
    Enum.with_index(args, fn
      {:ann_type, _, [{:var, _, name}, {:type, _, type, []}]}, _i ->
        {name, type}

      {:type, _, type, []}, i ->
        {:"arg_#{i}", type}
    end)
  end

  defp normalize_type({:type, _, atom, []}) when is_atom(atom) do
    atom
  end
end
