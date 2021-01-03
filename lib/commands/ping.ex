defmodule CAIBot.Commands.Public.Ping do
  @behaviour Nosedrum.Command

  alias Nostrum.Api

  @impl true
  def usage, do: ["!ping"]

  @impl true
  def description, do: "Ping the bot."

  @impl true
  def predicates, do: []

  @impl true
  def command(message, _args) do
    {:ok, _msg} = Api.create_message(message.channel_id, "Pong!")
  end
end
