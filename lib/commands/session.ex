defmodule CAIBot.Commands.PlanetSide.Session do
  @behaviour Nosedrum.Command

	alias Nostrum.Api
	alias Nostrum.Struct.Embed

	import Predicates
	import Utils, only: [safe_div: 3, safe_div: 2]

  @impl true
  def usage, do: ["!session <character name>"]

  @impl true
  def description, do: "View a player's most recent session stats."

	@impl true
	def parse_args([character_name]), do: character_name

  @impl true
	def predicates, do: [&ps2_username?/1]

  @impl true
	def command(message, character_name) do
		case CAIBot.get_data(CAIData, :get_session_by_name, [character_name]) do
			nil -> Api.create_message!(message.channel_id, "We don't have any session data for that character.")
			session ->
				experience_info = CAIBot.get_info(:experience)

				top_xp_sources = if map_size(session.xp_types) > 0 do
					Enum.sort(session.xp_types, fn {_xp_id_1, value_1}, {_xp_id_2, value_2} -> value_1 >= value_2 end)
					|> Enum.take(10)
					|> Enum.map_join("\n", fn {xp_id, value} ->
						xp_info = experience_info[xp_id]
						"#{value}xp | #{safe_div(value, Map.get(xp_info, "xp")) |> ceil()}x | #{xp_info["description"]}"
					end)
				else
					"No XP Stats"
				end

				general_stats = general_stats_desc(session)
				ivi_stats = ivi_stats_desc(session)

				embed =
					%Embed{}
					|> Embed.put_title(session.name)
					|> Embed.put_field("General Stats", general_stats, true)
					|> Embed.put_field("Infantry vs. Infantry", ivi_stats, true)
					|> Embed.put_field("XP Stats", "**XP Earned -** #{session.xp_earned}\n**Top 8 XP sources**:\n**Total XP | Amount | XP type**\n#{top_xp_sources}")

				Api.create_message!(message.channel_id, embed: embed)
		end
  end

	defp general_stats_desc(session) do
		session_seconds = session.logout_timestamp - session.login_timestamp
		vehicles_destroyed_card = Enum.map_join(session.vehicles_destroyed, "\n", fn {name, amount} -> "#{amount}x #{name}" end)
		vehicles_lost_card = Enum.map_join(session.vehicles_lost, "\n", fn {name, amount} -> "#{amount}x #{name}" end)

		"""
		**Player Kills**: #{session.kills}
		**Player Deaths**: #{session.deaths}
		**KDR**: #{safe_div(session.kills, session.deaths)}
		**KPM**: #{safe_div(session.kills, session_seconds, default: 0) * 60}
		**--==+==--**
		**Vehicle Kills**: #{session.vehicle_kills}
		**Vehicle Deaths**: #{session.vehicle_deaths}
		**VKDR**: #{safe_div(session.vehicle_kills, session.vehicle_deaths)}
		**Vehicle Bails**: #{session.vehicle_bails}
		**Vehicles Destroyed**: #{vehicles_destroyed_card}
		**Vehicles Lost**: #{vehicles_lost_card}
		**Nanites Destroyed:Used** #{session.nanites_destroyed}:#{session.nanites_lost}
		**--==+==--**
		**Play Time**: #{Utils.time_since_epoch(session_seconds)}
		**Last Logout**: #{session.logout_timestamp |> DateTime.from_unix!()}
		"""
	end

	defp ivi_stats_desc(session) do

		hsr = safe_div(session.kills_hs * 100, session.kills_ivi, default: 0)
		accuracy = safe_div(session.shots_hit * 100, session.shots_fired, default: 0)

		"""
		**HSR**: #{hsr}%
		**Accuracy**: #{session.archived == 1 && "#{accuracy}%" || "Pending API update..."}
		**Score**: #{session.archived == 1 && Float.round(hsr * accuracy, 2) || "Pending API update..."}
		**--==+==--**
		**Kills**: #{session.kills_ivi}
		**Deaths**: #{session.deaths_ivi}
		**KDR**: #{safe_div(session.kills_ivi, session.deaths_ivi)}
		**KPM**: #{safe_div(session.kills_ivi * 60, session.logout_timestamp - session.login_timestamp)}
		**--==+==--**
		**SPK**: #{session.archived == 1 && safe_div(session.shots_fired, session.kills_ivi) || "Pending API update..."},
		**HPK**: #{session.archived == 1 && safe_div(session.shots_hit, session.kills_ivi) || "Pending API update..."},
		"""
	end
end
