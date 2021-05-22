defmodule CAIBot do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      Nosedrum.Storage.ETS,
      CAIBot.ReactionHandler,
      {CAIBot.Consumer, name: CAIBot.Consumer}
    ]

    opts = [strategy: :one_for_one, name: CAIBot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def reaction_map,
    do: [
      "1️⃣",
      "2️⃣",
      "3️⃣",
      "4️⃣",
      "5️⃣",
      "6️⃣",
      "7️⃣",
      "8️⃣",
      "9️⃣",
      "🔟"
    ]
end
