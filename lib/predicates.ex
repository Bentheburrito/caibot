defmodule Predicates do
	def ps2_username?(%Nostrum.Struct.Message{content: content}) do
		[_command | [char_name]] = String.split(content, " ")
		if String.length(char_name) < 3 or String.contains?(char_name, " ") do
			{:noperm, "Character names must be at least 3 characters long and contain no spaces."}
		else
			:passthrough
		end
	end
end
