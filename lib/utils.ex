defmodule Utils do
  def time_since_epoch(timestamp) do
    second_diff = DateTime.diff(DateTime.utc_now(), DateTime.from_unix!(timestamp))
    time = Time.add(~T[00:00:00], second_diff)

    ["#{time.hour}h", "#{time.minute}m", "#{time.second}s"]
    |> Enum.filter(&(String.first(&1) != "0"))
    |> Enum.join(" ")
  end

  def format_unix_offset(timestamp) do
    dt = DateTime.from_unix!(timestamp)

    ["#{dt.day - 1}d", "#{dt.hour}h", "#{dt.minute}m", "#{dt.second}s"]
    |> Enum.filter(&(String.first(&1) != "0"))
    |> Enum.join(" ")
  end

  def grammar_possessive(string) do
    if String.ends_with?(string, "s"), do: string <> "'", else: string <> "'s"
  end

  def safe_div(a, b, options \\ [])

  def safe_div(a, b, options) when not is_integer(a) or not is_integer(b),
    do: Keyword.get(options, :default, "N/A")

  def safe_div(a, 0, _options), do: a
  def safe_div(a, b, options), do: (a / b) |> Float.round(Keyword.get(options, :round_to, 2))

  def react_in_order(message, emoji_list),
    do: react_in_order(message.channel_id, message.id, emoji_list)

  def react_in_order(channel_id, message_id, emoji_list) do
    Task.start(fn ->
      Enum.each(emoji_list, fn emoji ->
        Nostrum.Api.create_reaction(channel_id, message_id, emoji)
        Process.sleep(200)
      end)
    end)
  end
end
