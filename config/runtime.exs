import Config

if Config.config_env() == :dev do
  DotenvParser.load_file(".env")
end

config :caibot,
  data_hostname:
    ("data@" <> (:inet.gethostname() |> elem(1) |> List.to_string())) |> String.to_atom()

config :nostrum,
  token: System.get_env("CAI_TOKEN"),
  num_shards: :auto

config :planetside_api, service_id: System.get_env("SERVICE_ID"), event_streaming: false
