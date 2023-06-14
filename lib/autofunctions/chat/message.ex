defmodule Autofunctions.Chat.Message do
  defstruct [
    :role,
    :name,
    :content,
    :function_call,
    :mfa
  ]

  @type t :: %__MODULE__{
          role: :system | :assistant | :user | :function,
          name: String.t() | nil,
          content: String.t() | nil,
          function_call: map() | nil,
          mfa: {module(), atom(), [term()]} | nil
        }

  def assistant(json, mod \\ nil)

  def assistant(%{function_call: %{} = fun_call}, mod) do
    %__MODULE__{
      role: :assistant,
      function_call: fun_call,
      mfa: Autofunctions.get_call(mod, fun_call)
    }
  end

  def assistant(%{content: content}, _mod) do
    %__MODULE__{role: :assistant, content: content}
  end

  def system(%{content: content}) do
    %__MODULE__{role: :system, content: content}
  end

  def user(%{content: content}) do
    %__MODULE__{role: :user, content: content}
  end

  def function(%{name: function_name, content: content}) do
    %__MODULE__{role: :function, name: function_name, content: content}
  end

  def to_json(%__MODULE__{role: role, content: content} = message) do
    %{role: role, content: content}
    |> put_non_nil(:name, message.name)
    |> put_non_nil(:function_call, message.function_call)
  end

  defp put_non_nil(map, _k, nil), do: map
  defp put_non_nil(map, k, v), do: Map.put(map, k, v)
end
