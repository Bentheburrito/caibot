import Config

config :caibot, data_hostname: "data@" <> (:inet.gethostname |> elem(1) |> List.to_string()) |> String.to_atom()
