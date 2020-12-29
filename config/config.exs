import Config

config :caibot, data_hostname: "data@" <> (:inet.gethostname |> elem(1) |> List.to_string()) |> String.to_atom()


config :nostrum,
	token: System.get_env("CAI_TOKEN"),
	num_shards: :auto

config :nosedrum,
  prefix: "!"

config :planetside_api, service_id: System.get_env("SERVICE_ID"), event_streaming: false
