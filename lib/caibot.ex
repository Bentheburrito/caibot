defmodule CAIBot do
	@moduledoc false
  use Application

  def start(_type, _args) do
    children = [
			Nosedrum.Storage.ETS,
			{CAIBot.Consumer, name: CAIBot.Consumer}
		]

    opts = [strategy: :one_for_one, name: CAIBot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
