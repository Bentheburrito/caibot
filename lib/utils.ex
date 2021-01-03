defmodule Utils do
	def time_since_epoch(timestamp) do
		second_diff = DateTime.diff(DateTime.utc_now(), DateTime.from_unix!(timestamp))
		time = Time.add(~T[00:00:00], second_diff)
		["#{time.hour}h", "#{time.minute}m", "#{time.second}s"]
		|> Enum.filter(& String.first(&1) != "0")
		|> Enum.join(" ")
	end

	def grammar_possessive(string) do
		if String.ends_with?(string, "s"), do: string <> "'", else: string <> "'s"
	end

	def safe_div(a, b, options \\ [])
	def safe_div(a, b, options) when a == "N/A" or b == "N/A", do: Keyword.get(options, :default, "N/A")
	def safe_div(a, 0, _options), do: a
	def safe_div(a, b, options), do: a / b |> Float.round(Keyword.get(options, :round_to, 2))
end
