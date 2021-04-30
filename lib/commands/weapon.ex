defmodule CAIBot.Commands.PlanetSide.Weapon do
	@behaviour Nosedrum.Command

	require Logger

	alias Nostrum.Api
	alias Nostrum.Struct.Embed
	alias PS2.API.{Query, Join, QueryResult}

	import Predicates
	import PS2.API.QueryBuilder

	@excluded_item_categories [99, 103, 105, 106, 107, 108, 133, 134, 135, 136, 137, 139, 140, 141, 142, 143, 145, 148]

  @impl true
  def usage, do: ["!weapon weapon_name"]

  @impl true
	def description, do: "View general information about a weapon."

	@impl true
  def parse_args(args), do: Enum.join(args, " ")

  @impl true
  def predicates, do: [&ps2_weapon_name?(&1, 1)]

  @impl true
	def command(message, weapon_name) do
		query =
			Query.new(collection: "item")
			|> term("name.en", String.downcase(weapon_name), :contains)
			|> case_sensitive(false)
			|> show(["item_id", "item_category_id", "is_vehicle_weapon", "name.en", "description.en", "faction_id", "image_id", "is_default_attachment"])
			|> limit(10)
			|> join(%Join{collection: "weapon_datasheet"} |> inject_at("weapon") |> show(["damage", "damage_min", "damage_max", "fire_cone", "fire_rate_ms", "reload_ms", "clip_size", "capacity", "range.en"]))
			|> term("item_category_id", @excluded_item_categories, :not)

		with {:ok, %QueryResult{data: weapon_list, returned: returned}} when returned > 0 <- PS2.API.query(query) do

			Api.start_typing(message.channel_id)

			weapons = weapon_list
			# |> Enum.filter(fn item -> is_map_key(item, "weapon") and !String.contains?(item["name"]["en"], "AE") end))
			# |> Enum.dedup()

			weapon_stats =
				if length(weapons) > 1,
					do: clarify_user_choice(message, weapons),
					else: List.first(weapons)

			# Create embed with weapon stats and send.
			if not is_nil(weapon_stats) do
				embed = %Embed{}
				|> Embed.put_title(weapon_stats["name"]["en"])
				|> Embed.put_field("Stats", weapon_stat_desc(Map.get(weapon_stats, "weapon", %{})), true)
				|> Embed.put_field("Description", weapon_stats["description"]["en"])

				Api.create_message!(message.channel_id, embed: embed)
			end
		else
			{:ok, %QueryResult{returned: 0}} -> Api.create_message(message.channel_id, "No weapon found.")
			{:error, error} ->
				Api.create_message(message.channel_id, "An error occurred while fetching the weapon. Please try again in a bit (and make sure the name is spelled correctly.)")
				Logger.error("Query Error for command !weapon #{weapon_name}: #{inspect error}")
		end
	end

	defp weapon_stat_desc(weapon) do
		clip_size = weapon |> Map.get("clip_size", 0) |> String.to_integer()
		ammo_capacity = weapon |> Map.get("capacity", 0) |> String.to_integer()

		"""
		**Damage (min, max)**: #{Map.get(weapon, "damage", "N/A")} (#{weapon["damage_min"]}, #{weapon["damage_max"]})
		**RPM**: #{String.to_integer(weapon["fire_rate_ms"]) / 1000 * 60 |> Float.round(2)}
		**Reload Speed**: #{String.to_integer(weapon["reload_ms"]) / 1000 |> Float.round(2)}s
		**Magazine Size / Reserve**: #{clip_size} / #{ammo_capacity - clip_size}
		"""
	end

	# Prompt the user to select one of the weapons that match their search.
	defp clarify_user_choice(message, weapons) do
		init_embed = %Embed{}
		|> Embed.put_title("Multiple weapons found")
		|> Embed.put_description("React to select a weapon")

		# embed for the prompt message, weapon_selection_map is a map of emoji.name => a_weapons_stats.
		{embed, weapon_selection_map, _emotes} = Enum.reduce_while(weapons, {init_embed, %{}, CAIBot.reaction_map}, fn
			%{"name" => %{"en" => name}, "description" => %{"en" => desc}} = weapon, {embed, weapon_selection_map, [reaction | emotes]} ->
				{:cont, {Embed.put_field(embed, "#{reaction} for #{name}", String.split(desc, ".") |> hd()), Map.put(weapon_selection_map, reaction, weapon), emotes}}
			_weapon, {_embed, _weapon_selection_map, []} = acc -> {:halt, acc}
		end)

		# Send the prompt/embed with the list of found weapons.
		%Nostrum.Struct.Message{} = prompt = Api.create_message!(message.channel_id, embed: embed)

		# Have the bot react on the prompt.
		Utils.react_in_order(prompt, Enum.take(CAIBot.reaction_map, length(weapons)))

		# Await the author's reaction.
		case CAIBot.ReactionHandler.await_reaction(prompt.id, users: [message.author.id]) do
			{:ok, reaction} ->
				# Delete the prompt message.
				Api.delete_message!(prompt)

				# Return the weapon stats.
				weapon_selection_map[reaction.emoji.name]

			:timeout ->
				Api.create_message!(message.channel_id, "Cancelling !weapon command, user ran out of time to react.")
				nil
		end
	end
end
