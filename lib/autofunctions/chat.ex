defmodule Autofunctions.Chat do
  alias Autofunctions.Chat
  alias Autofunctions.Chat.Message

  @system_message """
  You are a helpful assistant. Be concise in all replies.
  """

  @derive {Inspect, except: [:api_key]}
  defstruct [
    :api_key,
    :functions_module,
    model: "gpt-3.5-turbo-0613",
    messages: [
      Message.system(%{content: @system_message})
    ]
  ]

  def new(functions_module, opts \\ []) do
    api_key = fetch_api_key!(opts)

    %__MODULE__{api_key: api_key, functions_module: functions_module}
  end

  defp fetch_api_key!(opts) do
    key =
      opts[:api_key] || System.get_env("LB_OPENAI_API_KEY") || System.get_env("OPENAI_API_KEY")

    key || raise "missing :api_key"
  end

  def add(%Chat{} = chat, %Message{} = message) do
    %{chat | messages: [message | chat.messages]}
  end

  def user_message(%Chat{} = chat, content) when is_binary(content) do
    add(chat, Message.user(%{content: content}))
  end

  def run_function(%Chat{messages: [most_recent | _]} = chat) do
    case most_recent do
      %{role: :assistant, function_call: %{name: name}, mfa: {m, f, a}} ->
        result = apply(m, f, a)
        add(chat, Message.function(%{name: name, content: result}))

      _ ->
        chat
    end
  end

  def send!(%Chat{} = chat) do
    resp =
      chat
      |> req()
      |> Req.post!(
        url: "/v1/chat/completions",
        decode_json: [keys: :atoms],
        json: %{
          model: chat.model,
          functions: Autofunctions.get_functions(chat.functions_module),
          # TODO: use Jason.Encoder, but can't in Livebook due to protocol
          # already being consolidated
          messages:
            chat.messages
            |> Enum.map(&Message.to_json/1)
            |> Enum.reverse()
        }
      )

    case resp do
      %{status: 200, body: %{choices: [%{message: message} | _]}} ->
        add(chat, Message.assistant(message, chat.functions_module))

      error ->
        IO.warn("Error: #{inspect(error)}")
        raise "bad resp"
    end
  end

  defp req(%{api_key: api_key}) do
    Req.new(
      base_url: "https://api.openai.com",
      auth: {:bearer, api_key}
    )
  end

  defimpl Kino.Render do
    def to_livebook(%{messages: messages}) do
      messages
      |> Enum.reverse()
      |> Enum.map(fn
        %{role: :assistant, mfa: {_, _, _} = mfa} ->
          """

          **assistant [function call]:** #{inspect(mfa)}
          """

        %{role: :function, content: content} ->
          """

          **function:** #{inspect(content)}
          """

        %{role: role, content: content} when is_binary(content) ->
          """

          **#{role}:** #{String.trim(content)}
          """
      end)
      |> Enum.join("")
      |> Kino.Markdown.new()
      |> Kino.Render.to_livebook()
    end
  end
end
