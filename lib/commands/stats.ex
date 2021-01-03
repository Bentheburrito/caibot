defmodule CAIBot.Commands.PlanetSide.Stats do
	@behaviour Nosedrum.Command
	@required_fields [
		"weapon_fire_count",
		"weapon_play_time",
		"weapon_score",
	]

	require Logger

	alias Nostrum.Api
	alias Nostrum.Struct.Embed
	alias PS2.API.{Query, Join}

	import Predicates
	import PS2.API.QueryBuilder

  @impl true
  def usage, do: ["!stats character_name", "!stats character_name weapon_name"]

  @impl true
	def description, do: "View a character's stats, or a character's stats for a particular weapon."

	@impl true
	def parse_args(args), do: [hd(args), tl(args) |> Enum.join(" ")]

  @impl true
  def predicates, do: [&ps2_username?/1, &ps2_weapon_name?(&1, 2)]

	# @impl true
  # def command(msg, [character_name]) do

  # end

  @impl true
	def command(message, [character_name, weapon_name]) do
		Api.start_typing(message.channel_id)
		weapon_name_simplified = String.replace(weapon_name, [" ", "-"], "") |> String.downcase()
		case Enum.find(CAIBot.get_info(:weapon), & String.replace(&1, [" ", "-"], "") |> String.downcase() |> String.contains?(weapon_name_simplified)) do
			nil -> Api.create_message!(message.channel_id, "No weapon by that name.")
			weapon_name_formatted ->
				query = # Put this query into a defp, turn nested cases into with
					Query.new(collection: "character_name")
					|> term("name.first_lower", String.downcase(character_name), :contains)
					|> exact_match_first(true)
					|> join(Join.new(collection: "characters_weapon_stat")
						|> on("character_id")
						|> inject_at("w_stats")
						|> list(true)
						|> term("item_id", 0, :not)
						|> show(["item_id", "stat_name", "vehicle_id", "value", "last_save"])
						|> join(Join.new(collection: "item")
							|> inject_at("weapon")
							|> term("name.en", weapon_name_formatted)
							|> outer(false)
							|> show(["item_id", "name.en", "description.en", "faction_id"])
						)
					) |> join(Join.new(collection: "characters_weapon_stat_by_faction")
						|> on("character_id")
						|> inject_at("w_stats_f")
						|> list(true)
						|> term("item_id", 0, :not)
						|> show(["item_id", "stat_name", "vehicle_id", "value_vs", "value_tr", "value_nc", "last_save"])
						|> join(Join.new(collection: "item")
							|> inject_at("weapon")
							|> term("name.en", weapon_name_formatted)
							|> outer(false)
							|> show(["item_id", "name.en", "description.en", "faction_id"])
						)
					)
				case PS2.API.send_query(query) do
					{:ok, %{"character_name_list" => []}} -> Api.create_message(message.channel_id, "No character found.")
					{:ok, %{"character_name_list" => [%{"name" => %{"first" => name}, "w_stats" => w_stats, "w_stats_f" => w_faction_stats}]}} ->
						weapon_stats = w_stats ++ w_faction_stats
						|> Enum.reduce(%{}, fn # Build weapon stats in the form of %{weapon name => %{stat name => value, ...} ...}
							%{"stat_name" => stat_name, "value" => val, "weapon" => %{"name" => %{"en" => w_name}}}, acc ->
								value = String.to_integer(val)
								Map.update(acc, w_name, %{stat_name => value}, &Map.put(&1, stat_name, value))
							%{"stat_name" => stat_name, "value_nc" => val_nc, "value_vs" => val_vs, "value_tr" => val_tr, "weapon" => %{"name" => %{"en" => w_name}}}, acc ->
								value = String.to_integer(val_nc) + String.to_integer(val_vs) + String.to_integer(val_tr)
								Map.update(acc, w_name, %{stat_name => value}, &Map.put(&1, stat_name, value))
							_, acc -> acc
						end)
						|> Enum.filter(fn # Filter out "Anniversary Edition" weapons - may want to concat their stats onto the default version of the weapon later.
							{weapon, stats} ->
								stat_names = Map.keys(stats)
								not String.contains?(weapon, "AE") and Enum.all?(@required_fields, & &1 in stat_names)
						end)
						|> Enum.into(%{})

						if weapon_stats == %{} do
							Api.create_message(message.channel_id, "No #{weapon_name_formatted} stats for #{name} (Insufficient data.)")
						else
							{faction_name, faction_color, faction_logo} = CAIBot.get_info(:faction)[List.first(w_stats)["weapon"]["faction_id"]]

							base_embed = %Embed{}
							|> Embed.put_title("#{Utils.grammar_possessive(name)} weapon stats")
							|> Embed.put_color(faction_color)
							|> Embed.put_footer("#{faction_name} weapon - To view weapon properties like mag size, reload time, etc. use !weapon", faction_logo)

							embed = Enum.reduce(weapon_stats, base_embed, fn {weapon, weapon_stats}, cur_embed ->
								stats_description = char_weapon_stats_desc(weapon_stats)
								Embed.put_field(cur_embed, weapon, stats_description)
							end)

							Api.create_message!(message.channel_id, embed: embed)
						end

					{:ok, %{"character_name_list" => [%{"name" => %{"first" => name}}]}} ->
						Api.create_message(message.channel_id, "No #{weapon_name_formatted} stats for #{name} (Insufficient data.)")
					{:error, error} ->
						Api.create_message(message.channel_id, "An error occurred while fetching the character/weapon. Please try again in a bit (and make sure both names are spelled correctly.)")
						Logger.error("Query Error for command !stats #{character_name} #{weapon_name}: #{inspect error}")
				end
		end
	end

	defp char_weapon_stats_desc(base_stats) do
		kills = Map.get(base_stats, "weapon_kills", "N/A")
		deaths = Map.get(base_stats, "weapon_deaths", "N/A")
		headshot_kills = Map.get(base_stats, "weapon_headshots", 0)
		hsr = Utils.safe_div(headshot_kills * 100, kills, default:  0)

		shots_hit = Map.get(base_stats, "weapon_hit_count", 0)
		shots_fired = Map.get(base_stats, "weapon_fire_count", 0)
		accuracy = Utils.safe_div(shots_hit * 100, shots_fired, default: 0)

		seconds_used = Map.get(base_stats, "weapon_play_time", 0)

		"""
		**Kills**: #{kills}
		**Deaths**: #{deaths}
		**Vehicle Kills**: #{Map.get(base_stats, "weapon_vehicle_kills", "N/A")}
		**KDR**: #{Utils.safe_div(kills, deaths)}
		**HSR**: #{hsr}%
		**Accuracy**: #{accuracy}%
		**IvI Score**: #{accuracy * hsr |> Float.round(2)}
		**KPM**: #{Utils.safe_div(kills, seconds_used / 60)}
		**SPK**: #{Utils.safe_div(shots_fired, kills)}
		**HPK**: #{Utils.safe_div(shots_hit, kills)}
		**Time Used**: #{DateTime.utc_now() |> DateTime.to_unix() |> Kernel.-(seconds_used) |> Utils.time_since_epoch()}
		**Total Score**: #{Map.get(base_stats, "weapon_score", "N/A")}
		"""
	end
end
