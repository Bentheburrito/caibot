defmodule Predicates do
	def ps2_username?(%Nostrum.Struct.Message{content: content}) do
		[_command, char_name | _rest] = String.split(content, " ")
		if String.length(char_name) < 3 or String.contains?(char_name, " ") do
			{:noperm, "Character names must be at least 3 characters long and contain no spaces."}
		else
			:passthrough
		end
	end

	def ps2_weapon_name?(%Nostrum.Struct.Message{content: content}, index) do
		w_name_fragments = content |> String.split(" ") |> Enum.slice(index..100)
		weapon_name = Enum.join(w_name_fragments, " ")
		if String.length(weapon_name) < 3 and weapon_name != "" do
			{:noperm, "Weapon names must be at least 3 characters long."}
		else
			:passthrough
		end
	end
end
