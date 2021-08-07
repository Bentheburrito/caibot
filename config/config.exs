import Config

# For mix commands in dev enviroments, like "mix ecto.create"
config :caibot, CAIBot.Repo,
  database: "caibot",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"

config :caibot,
  ecto_repos: [CAIBot.Repo]


config :nosedrum,
  prefix: "!"
