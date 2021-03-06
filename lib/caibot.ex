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

	def get_info(type) do
		get_data(CAIData, String.to_atom("#{type}_info"), [])
	end

	def get_data(module, fn_name, args) do
		Task.Supervisor.async({CAIData.DataTasks, Application.get_env(:caibot, :data_hostname)}, module, fn_name, args)
		|> Task.await()
	end
end
