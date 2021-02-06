defmodule HeavyKeeper.MixProject do
  use Mix.Project

  def project do
    [
      app: :heavy_keeper,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:murmur, "~> 1.0"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:propcheck, "~> 1.3", github: "alfert/propcheck", only: [:dev, :test]}
    ]
  end
end
