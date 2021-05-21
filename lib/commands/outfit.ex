defmodule CAIBot.Commands.PlanetSide.Outfit do
	@behaviour Nosedrum.Command

	require Logger

	alias Nostrum.Api
	alias Nostrum.Struct.Embed
	alias PS2.API.{Query, Join, QueryResult}

	# import Predicates, only: [ps2_outfit_name?: 1]
	import PS2.API.QueryBuilder
	import Utils, only: [safe_div: 2]

  @impl true
  def usage, do: ["outfit name <outfit name>", "outfit tag <outfit tag>"]

  @impl true
	def description, do: "View an outfit's general info. Searches by outfit tag by default (See usage examples.)"

	@impl true
  def parse_args(args), do: Enum.join(args, " ")

  @impl true
  def predicates, do: []

	# outfit_identifier = an outfit name or tag
  @impl true
	def command(message, "name " <> outfit_identifier), do:	do_command(message, query_outfit_with_identifier("name_lower", String.downcase(outfit_identifier)))

	@impl true
	def command(message, "tag " <> outfit_identifier), do: command(message, outfit_identifier)

	@impl true
	def command(message, outfit_identifier), do: do_command(message, query_outfit_with_identifier("alias_lower", String.downcase(outfit_identifier)))

	defp do_command(message, %Query{} = query) do
		with {:ok, %QueryResult{data: %{"name" => name, "alias" => tag, "members" => members} = outfit}} <- PS2.API.query_one(query) do
			faction_id = List.first(members)["character"]["faction_id"]
			{faction_name, faction_color, faction_logo} = CAIData.API.get_info(:faction)[faction_id]

			%{"kills" => outfit_kills, "deaths" => outfit_deaths} = outfit_members_stats(members)
			outfit_kdr = safe_div(outfit_kills, outfit_deaths)
			online_member_cards = Enum.filter(members, fn member ->
				member["character"]["status"]["online_status"] not in ["0", nil]
			end)
			|> Enum.map_join("\n", fn member ->
				"**#{member["character"]["name"]["first"]}** / *#{member["rank"]}* (#{member["rank_ordinal"]})"
			end)
			|> String.slice(0..1023)

			embed = %Embed{}
			|> Embed.put_field("#{name} [#{tag}]", "#{faction_name} - #{outfit["member_count"]} members\nAvg. KDR: #{outfit_kdr}")
			|> Embed.put_field("Online Members:\nName / Rank (Rank Ordinal)", online_member_cards == "" && "No online members." || online_member_cards)
			|> Embed.put_color(faction_color)
			|> Embed.put_thumbnail(faction_logo)
			|> Embed.put_footer("Created #{outfit["time_created"] |> String.to_integer() |> DateTime.from_unix!() |> DateTime.to_date()}")

			Api.create_message!(message.channel_id, embed: embed)
		else
			{:ok, %QueryResult{returned: 0}} -> Api.create_message(message.channel_id, "No outfit found.")
			{:error, error} ->
				Api.create_message(message.channel_id, "An error occurred while fetching the outfit. Please try again in a bit (and make sure the name/tag is spelled correctly.)")
				Logger.error("Query Error for command !outfit: #{inspect error}")
		end
	end

	defp outfit_members_stats(members) do
		Enum.reduce(members, %{}, fn
			%{"character" => %{"stats" => stats}}, acc ->
				Enum.reduce(stats, acc, fn
					%{"stat_name" => stat_name, "all_time" => val}, cur_acc ->
						value = String.to_integer(val)
						Map.update(cur_acc, stat_name, value, &(&1 + value))
					_, cur_acc -> cur_acc
				end)
			_, acc -> acc
		end)
	end

	defp query_outfit_with_identifier(identifier_type, value) do
		Query.new(collection: "outfit")
		|> term(identifier_type, value, :contains)
		|> exact_match_first(true)
		|> join(Join.new(collection: "outfit_member")
			|> list(true)
			|> inject_at("members")
			|> show(["character_id", "rank_ordinal", "rank"])
			|> join(Join.new(collection: "character")
				|> show(["name", "faction_id"])
				|> inject_at("character")
				|> join(Join.new(collection: "characters_stat_history")
					|> list(true)
					|> inject_at("stats")
					|> term("stat_name", ["kills", "deaths"])
					|> show(["stat_name", "all_time"])
				)
				|> join(Join.new(collection: "characters_online_status")
					|> inject_at("status")
					|> hide("character_id")
				)
			)
		)
	end
end
