defmodule CAIBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :caibot,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {CAIBot, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dotenv_parser, "~> 1.2"},
      {:planetside_api, "~> 0.2.0"},
      {:caidata_api, github: "Bentheburrito/caidata_api"},
      {:nostrum, "~> 0.4"},
      {:nosedrum, "~> 0.3"},
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"}
    ]
  end
end
