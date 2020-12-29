defmodule CAIBot.Commands.PlanetSide.Character do
	@behaviour Nosedrum.Command

	require Logger

	alias Nostrum.Api
	alias Nostrum.Struct.Embed
	alias PS2.API.{Query, Join}

	import Predicates
	import PS2.API.QueryBuilder

  @impl true
  def usage, do: ["!character character_name"]

  @impl true
	def description, do: "Retrieve general stats of a character."

	@impl true
  def parse_args(args), do: List.first(args)

  @impl true
  def predicates, do: [&ps2_username?/1]

  @impl true
	def command(message, character_name) do
		query =
			Query.new(collection: "character")
			|> term("name.first_lower", String.downcase(character_name), :contains)
			|> exact_match_first(true)
			|> resolve("outfit,online_status,world")
			|> join(%Join{collection: "title"} |> inject_at("title") |> show("name.en"))

		case PS2.API.send_query(query) do
			{:ok, %{"character_list" => []}} -> Api.create_message(message.channel_id, "No character found.")
			{:ok, %{"character_list" => [%{"name" => %{"first" => name}, "times" => times, "certs" => certs, "online_status" => online_status} = character]}} ->
				{faction_name, faction_color, faction_logo} = CAIBot.get_info(:faction)[character["faction_id"]]
				outfit_tag = character["outfit"]["alias"]
				hours_played = times["minutes_played"] |> String.to_integer() |> div(60)
				cur_session_login = case CAIBot.get_data(CAIData, :get_active_session, [character["character_id"]]) do
					{:ok, session} -> session.login_timestamp * 1000
					:none -> times["last_login"] |> String.to_integer() |> Kernel.*(1000)
				end
				embed =
					%Embed{}
					|> Embed.put_title(["[#{outfit_tag}]", character["title"]["name"]["en"], name] |> Enum.filter(& not is_nil(&1) and &1 != "[]") |> Enum.join(" "))
					|> Embed.put_description([CAIBot.get_info(:world)[character["world_id"]], faction_name, "[#{outfit_tag}] #{Map.get(character, "outfit")["name"]}" |> String.trim] |> Enum.filter(& not is_nil(&1) and &1 != "[]") |> Enum.join(", "))
					|> Embed.put_field("Battle Rank #{character["battle_rank"]["value"]}", "Prestige: #{character["prestige_level"]}")
					|> Embed.put_field("#{hours_played} hours in game", "Total Certs over Lifetime: #{String.to_integer(certs["earned_points"]) + String.to_integer(certs["gifted_points"])}")
					|> Embed.put_color(faction_color)
					|> Embed.put_thumbnail(faction_logo)
					#.setFooter(character.online_status > 0 ? `Online for ${sessionStamp} - ${character.character_id}` : `Offline - Last seen ${new Date(character.times.last_save * 1000).toLocaleDateString("en-US", { timeZone: timezone })} - ${character.character_id}`,
				#character.online_status > 0 ? "https://i.imgur.com/hxZ9HC4.png" : "https://i.imgur.com/KenvqDV.png")
					|> Embed.put_footer(online_status == "0" && "Offline - Last seen #{times["last_save"] |> String.to_integer() |> DateTime.from_unix!() |> DateTime.to_date()}" || "Online for #{DateTime.diff(DateTime.utc_now(), DateTime.from_unix!(cur_session_login))}" <> " - #{character["character_id"]}",
						online_status == "0" && "https://i.imgur.com/KenvqDV.png" || "https://i.imgur.com/hxZ9HC4.png")

				Api.create_message!(message.channel_id, embed: embed)
			{:error, error} ->
				Api.create_message(message.channel_id, "An error occurred while fetching the character. Please try again in a bit (and make sure their name is spelled correctly.)")
				Logger.error("Query Error for command !character #{character_name}: #{inspect error}")
		end
	end
end
