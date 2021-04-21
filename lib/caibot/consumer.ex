defmodule CAIBot.Consumer do
	use Nostrum.Consumer

	alias Nostrum.Api
	alias Nosedrum.Invoker.Split, as: CommandInvoker
  alias Nosedrum.Storage.ETS, as: CommandStorage

  def start_link do
		Consumer.start_link(__MODULE__)
  end

	def handle_event({:MESSAGE_CREATE, message, _ws_state}) do
		CommandInvoker.handle_message(message, CommandStorage)

		if Enum.random(1..40) == 1, do: Api.create_reaction(message.channel_id, message.id, Enum.random(["thonk:381325006761754625", "🤔", "😂", "😭"]))
	end

	def handle_event({:MESSAGE_REACTION_ADD, reaction, _ws_state}) do
		IO.inspect reaction
		CAIBot.ReactionHandler.register_reaction(reaction)
	end

	def handle_event({:READY, data, _ws_state}) do
		with {:ok, module_list} <- :application.get_key(:caibot, :modules) do
			module_list
			|> Enum.filter(& &1 |> Module.split |> Enum.member?("Commands"))
			|> Enum.each(fn m ->
				CommandStorage.add_command([m |> Module.split |> List.last |> String.downcase], m)
			end)
		end

		IO.puts("Logged in under #{data.user.username}##{data.user.discriminator} - Serving #{length(data.guilds)} guilds")
		Api.update_status(:dnd, "PlanetSide 2")
	end

	def handle_event(_event), do: :noop
end
