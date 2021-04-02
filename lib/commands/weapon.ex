defmodule CAIBot.Commands.PlanetSide.Weapon do
	@behaviour Nosedrum.Command

	require Logger

	alias Nostrum.Api
	alias Nostrum.Struct.Embed
	alias PS2.API.{Query, Join}

	import Predicates
	import PS2.API.QueryBuilder

	@excluded_item_categories [99, 103, 105, 106, 107, 108, 133, 134, 135, 136, 137, 139, 140, 141, 142, 143, 145, 148]

  @impl true
  def usage, do: ["!weapon weapon_name"]

  @impl true
	def description, do: "View general information about a weapon."

	@impl true
  def parse_args(args), do: List.first(args)

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

		case PS2.API.send_query(query) do
			{:ok, %{"item_list" => []}} -> Api.create_message(message.channel_id, "No weapon found.")
			{:ok, %{"item_list" => weapon_list}} ->

				Api.start_typing(message.channel_id)

				weapons = weapon_list
				# |> Enum.filter(fn item -> is_map_key(item, "weapon") and !String.contains?(item["name"]["en"], "AE") end))
				# |> Enum.dedup()

				case map_size(weapons) do
					0 ->
						Api.create_message!(message.channel_id, "No weapon found.")
					size when size > 1 ->
						init_embed = %Embed{}
						|> Embed.put_title("Multiple weapons found")
						|> Embed.put_description("React to select a weapon")

						embed = Enum.reduce(weapons, {init_embed, CAIBot.reaction_map}, fn %{"name" => %{"en" => name}, "description" => %{"en" => desc}}, {embed, [reaction | emotes]} ->
							{Embed.put_field(embed, "#{reaction} for #{name}", String.split(desc, ".") |> hd()), emotes}
						end)

						# Send the prompt/embed with the list of found weapons.
						%Nostrum.Struct.Message{} = prompt = Api.create_message!(message.channel_id, embed: embed)

						# Have the bot react on the prompt.
						Enum.each(Enum.take(CAIBot.reaction_map, map_size(weapons)), &Api.create_reaction!(message.channel_id, prompt.id, &1))

						# Await the author's reaction.
						{:ok, reaction} = CAIBot.ReactionHandler.await_reaction(prompt.id, users: [prompt.author.id])

						Api.delete_message!(prompt)


				end
		end
	end
end
