defmodule CAIBot.Repo do
  use Ecto.Repo,
    otp_app: :caibot,
    adapter: Ecto.Adapters.Postgres
end
