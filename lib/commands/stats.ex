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
	alias PS2.API.{Query, Join, QueryResult}

	import Predicates
	import PS2.API.QueryBuilder
	import Utils, only: [safe_div: 3, safe_div: 2]

  @impl true
  def usage, do: ["!stats character_name", "!stats character_name weapon_name"]

  @impl true
	def description, do: "View a character's stats, or a character's stats for a particular weapon."

	@impl true
	def parse_args([character_name]), do: character_name
	def parse_args(args), do: [hd(args), tl(args) |> Enum.join(" ")]

  @impl true
  def predicates, do: [&ps2_username?/1, &ps2_weapon_name?(&1, 2)]

	@impl true
	def command(message, [character_name, weapon_name]) do

		Api.start_typing(message.channel_id)

		weapon_name_simplified = String.replace(weapon_name, [" ", "-"], "") |> String.downcase()
		with weapon_name_matched when not is_nil(weapon_name_matched) <- Enum.find(CAIBot.get_info(:weapon), & String.replace(&1, [" ", "-"], "") |> String.downcase() |> String.contains?(weapon_name_simplified)),
			query <- char_weapon_stats_query(character_name, weapon_name_matched),
			{:ok, %QueryResult{data: %{"name" => %{"first" => name}, "w_stats" => w_stats, "w_stats_f" => w_faction_stats}}} <- PS2.API.query_one(query),
			weapon_stats when weapon_stats != %{} <- build_weapon_stats(w_stats, w_faction_stats) do

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
		else
			nil -> Api.create_message!(message.channel_id, "No weapon by that name.")
			{:ok, %{"character_name_list" => []}} -> Api.create_message(message.channel_id, "No character found.")
			{:ok, %{"character_name_list" => [%{"name" => %{"first" => name}}]}} ->
				Api.create_message(message.channel_id, "No #{weapon_name} stats for #{name} (Insufficient data.)")
			{:error, error} ->
				Api.create_message(message.channel_id, "An error occurred while fetching the character/weapon. Please try again in a bit (and make sure both names are spelled correctly.)")
				Logger.error("Query Error for command !stats #{character_name} #{weapon_name}: #{inspect error}")
			weapon_stats when weapon_stats == %{} ->
				Api.create_message(message.channel_id, "No #{weapon_name} stats for #{character_name} (Insufficient data.)")
		end
	end

	@impl true
  def command(message, character_name) do
		Api.start_typing(message.channel_id)
		with query <- char_stats_query(character_name),
			{:ok, %QueryResult{data: %{"name" => %{"first" => name}, "faction_id" => faction_id, "lt_stats" => lifetime_stats, "f_stats" => faction_stats} = character}} <- PS2.API.query_one(query),
			character_stats when character_stats != %{} <- build_char_stats(lifetime_stats, faction_stats, Map.get(character, "shot_stats", []), Map.get(character, "weapon_shot_stats", []), Map.get(character, "weapon_f_stats", [])) do
				{_faction_name, faction_color, faction_logo} = CAIBot.get_info(:faction)[faction_id]
				{lifetime_stats, ivi_stats} = char_stats_desc(character_stats, character)
				embed = %Embed{}
				|> Embed.put_title(name)
				|> Embed.put_field("Stats", lifetime_stats, true)
				|> Embed.put_field("IvI Stats", ivi_stats, true)
				|> Embed.put_color(faction_color)
				|> Embed.put_footer(character["character_id"], faction_logo)

				Api.create_message!(message.channel_id, embed: embed)
			else
				{:ok, %{"character_list" => []}} -> Api.create_message(message.channel_id, "No character found.")
				{:ok, %{"character_list" => [%{"name" => %{"first" => name}}]}} ->
					Api.create_message(message.channel_id, "No stats for #{name} (Insufficient data.)")
				{:error, error} ->
					Api.create_message(message.channel_id, "An error occurred while fetching the character. Please try again in a bit (and make sure their name is spelled correctly.)")
					Logger.error("Query Error for command !stats #{character_name}: #{inspect error}")
				character_stats when character_stats == %{} ->
					Api.create_message(message.channel_id, "No stats for #{character_name} (Insufficient data.)")
			end
  end

	defp char_stats_desc(base_stats, %{"times" => times}) do
		kills = Map.get(base_stats, "kills", "N/A")
		vehicle_kills = Map.get(base_stats, "weapon_vehicle_kills", "N/A")
		headshot_kills = Map.get(base_stats, "weapon_headshots", 0)
		infantry_deaths =  Map.get(base_stats, "weapon_deaths", "N/A")
		infantry_kills =  Map.get(base_stats, "weapon_kills", "N/A")
		deaths = Map.get(base_stats, "deaths", "N/A")

		shots_fired = Map.get(base_stats, "weapon_fire_count", 0)
		shots_hit = Map.get(base_stats, "weapon_hit_count", 0)
		hsr = safe_div(headshot_kills * 100, infantry_kills, default: 0)
		accuracy = safe_div(shots_hit * 100, shots_fired, default: 0)

		stats = """
		**Kills**: #{kills}
		**Vehicle Kills**: #{vehicle_kills}
		**Deaths**: #{deaths}
		**--==+==--**
		**KDR**: #{safe_div(kills, deaths)}
		**KPM**: #{safe_div(kills, String.to_integer(times["minutes_played"]))}
		**--==+==--**
		**Created**: #{times["creation"] |> String.to_integer() |> DateTime.from_unix!() |> DateTime.to_date()}
		**Time In Game**: #{safe_div(String.to_integer(times["minutes_played"]), 60)} hours
		**Last Seen**: #{times["last_save"] |> String.to_integer() |> DateTime.from_unix!() |> DateTime.to_date()}
		"""
		ivi = """
		**HSR**: #{hsr}%
		**Accuracy**: #{accuracy}%
		**Score**: #{Float.round(hsr * accuracy, 2)}
		**--==+==--**
		**KDR**: #{safe_div(infantry_kills, infantry_deaths)}
		**SPK**: #{safe_div(shots_fired, infantry_kills)}
		**HPK**: #{safe_div(shots_hit, infantry_kills)}
		"""
		{stats, ivi}
	end

	defp char_weapon_stats_desc(base_stats) do
		kills = Map.get(base_stats, "weapon_kills", "N/A")
		deaths = Map.get(base_stats, "weapon_deaths", "N/A")
		headshot_kills = Map.get(base_stats, "weapon_headshots", 0)
		hsr = safe_div(headshot_kills * 100, kills, default:  0)

		shots_hit = Map.get(base_stats, "weapon_hit_count", 0)
		shots_fired = Map.get(base_stats, "weapon_fire_count", 0)
		accuracy = safe_div(shots_hit * 100, shots_fired, default: 0)

		seconds_used = Map.get(base_stats, "weapon_play_time", 0)

		"""
		**Kills**: #{kills}
		**Deaths**: #{deaths}
		**Vehicle Kills**: #{Map.get(base_stats, "weapon_vehicle_kills", "N/A")}
		**KDR**: #{safe_div(kills, deaths)}
		**HSR**: #{hsr}%
		**Accuracy**: #{accuracy}%
		**IvI Score**: #{accuracy * hsr |> Float.round(2)}
		**KPM**: #{safe_div(kills, seconds_used / 60)}
		**SPK**: #{safe_div(shots_fired, kills)}
		**HPK**: #{safe_div(shots_hit, kills)}
		**Time Used**: #{DateTime.utc_now() |> DateTime.to_unix() |> Kernel.-(seconds_used) |> Utils.time_since_epoch()}
		**Total Score**: #{Map.get(base_stats, "weapon_score", "N/A")}
		"""
	end

	defp char_stats_query(character_name) do
		Query.new(collection: "character")
		|> term("name.first_lower", String.downcase(character_name), :contains)
		|> exact_match_first(true)
		|> show(["character_id", "name", "faction_id", "times.creation", "times.minutes_played", "times.last_save"])
		|> join(Join.new(collection: "characters_stat_history")
			|> list(true)
			|> term("stat_name", ["kills", "deaths", "facility_capture", "facility_defend", "all_time"])
			|> inject_at("lt_stats")
		)
		|> join(Join.new(collection: "characters_stat_by_faction")
			|> list(true)
			|> term("stat_name", "weapon_vehicle_kills")
			|> inject_at("f_stats")
			|> show(["character_id", "stat_name", "profile_id", "value_forever_vs", "value_forever_tr", "value_forever_nc", "last_save"])
		)
		|> join(Join.new(collection: "characters_stat")
			|> list(true)
			|> term("stat_name", "weapon_deaths")
			|> inject_at("shot_stats")
			|> show(["stat_name", "value_forever", "last_save"])
		)
		|> join(Join.new(collection: "characters_weapon_stat_by_faction")
			|> list(true)
			|> term("stat_name", ["weapon_headshots", "weapon_kills"])
			|> term("vehicle_id", "0")
			|> term("item_id", "0", :not)
			|> inject_at("weapon_f_stats")
			|> hide(["character_id", "last_save", "last_save_date"])
			|> join(Join.new(collection: "item")
				|> term("item_category_id", [3, 5, 6, 7, 8, 12, 19, 24, 100, 102])
				|> inject_at("weapon")
				|> outer(false)
				|> show(["name.en", "item_category_id"])
			)
		)
		|> join(Join.new(collection: "characters_weapon_stat")
			|> list(true)
			|> term("stat_name", ["weapon_hit_count", "weapon_fire_count", "weapon_deaths"])
			|> term("vehicle_id", "0")
			|> term("item_id", "0", :not)
			|> inject_at("weapon_shot_stats")
			|> show(["stat_name", "item_id", "vehicle_id", "value"])
			|> join(Join.new(collection: "item")
				|> term("item_category_id", [3, 5, 6, 7, 8, 12, 19, 24, 100, 102])
				|> inject_at("weapon")
				|> outer(false)
				|> show(["name.en", "item_category_id"])
			)
		)
	end

	defp char_weapon_stats_query(character_name, weapon_name) do
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
				|> term("name.en", weapon_name)
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
				|> term("name.en", weapon_name)
				|> outer(false)
				|> show(["item_id", "name.en", "description.en", "faction_id"])
			)
		)
	end

	defp build_char_stats(lifetime_stats, faction_stats, shot_stats, weapon_faction_stats, weapon_shot_stats) do
		lifetime_stats ++ faction_stats ++ shot_stats ++ weapon_faction_stats ++ weapon_shot_stats
		|> Enum.reduce(%{}, fn
			%{"stat_name" => stat_name, "value_nc" => value_nc, "value_tr" => value_tr, "value_vs" => value_vs}, acc ->
				value = String.to_integer(value_nc) + String.to_integer(value_tr) + String.to_integer(value_vs)
				Map.update(acc, stat_name, value, & &1 + value)
			%{"stat_name" => stat_name, "value" => val}, acc ->
				value = String.to_integer(val)
				Map.update(acc, stat_name, value, & &1 + value)
			%{"stat_name" => stat_name, "value_forever" => val}, acc ->
				Map.put(acc, stat_name, String.to_integer(val))
			%{"stat_name" => stat_name, "value_forever_nc" => value_nc, "value_forever_tr" => value_tr, "value_forever_vs" => value_vs}, acc ->
				Map.put(acc, stat_name, String.to_integer(value_nc) + String.to_integer(value_tr) + String.to_integer(value_vs))
			%{"stat_name" => stat_name, "all_time" => val}, acc ->
				value = String.to_integer(val)
				Map.update(acc, stat_name, value, & &1 + value)
		end)
	end

	defp build_weapon_stats(weapon_stats, weapon_faction_stats) do
		weapon_stats ++ weapon_faction_stats
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
	end
end
