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
  def command(msg, _args) do
    {:ok, _msg} = Api.create_message(msg.channel_id, "Pong!")
  end
end
