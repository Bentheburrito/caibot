defmodule CAIBot.ReactionHandler do
	@moduledoc """
	Allows a caller to synchronously await a reaction on a message.
	"""
	use GenServer

	def start_link(init_state) do
		GenServer.start_link(__MODULE__, init_state, name: __MODULE__)
	end

	@doc """
	Await a reaction on the specified message. Optionally filter by certain users or emojis, or set a timeout.

	## Options

	* `:emojis` - a list of emoji names.
	* `:users` - a list of user ids.
	* `:timeout` - a timeout in milliseconds, or :infinity (defaults to 30_000).
	"""
	@spec await_reaction(Nostrum.Snowflake.t(), Keyword.t() | []) :: map() | :timeout
	def await_reaction(message_id, options \\ []) do
		GenServer.call(__MODULE__, {:await, message_id, options})
	end

	@doc """
	Register a reaction with ReactionHandler, returning it to any awaiting callers. This
	function is typically called from a Nostrum.Consumer :MESSAGE_REACTION_ADD event.
	"""
	def register_reaction(reaction) do
		GenServer.cast(__MODULE__, {:new_reaction, reaction})
	end

	def init(_state) do
		{:ok, %{}}
	end

	def handle_call({:await, message_id, options}, from, awaiting) do
		{timeout, filters} = Keyword.pop(options, :timeout, 30_000)
		if timeout != :infinity, do: Process.send_after(self(), {:timeout, {message_id, from}}, timeout)
		{:noreply, %{awaiting | message_id => {filters, from}}}
	end

	def handle_cast({:new_reaction, %{message_id: message_id} = reaction}, awaiting) when is_map_key(awaiting, message_id) do
		{filters, from} = Map.get(awaiting, message_id)
		if reaction.emoji.name in Keyword.get(filters, :emojis, [reaction.emoji.name]) and
			 reaction.member.user.id in Keyword.get(filters, :users, [reaction.member.user.id]) do

			GenServer.reply(from, {:ok, reaction})
			{:noreply, Map.delete(awaiting, message_id)}
		else
			{:noreply, awaiting}
		end
	end
	def handle_cast({:new_reaction, _message_id, _emoji, _user}, awaiting), do: {:noreply, awaiting}

	def handle_info({:timeout, {message_id, from}}, awaiting) when is_map_key(awaiting, message_id) do
		GenServer.reply(from, :timeout)
		{:noreply, Map.delete(awaiting, message_id)}
	end
	def handle_info({:timeout, _msg}, awaiting), do: {:noreply, awaiting}
end
