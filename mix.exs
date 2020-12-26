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
			{:planetside_api, "~> 0.1.2"},
			{:nostrum, "~> 0.4"},
			{:nosedrum, "~> 0.3"}
    ]
  end
end
