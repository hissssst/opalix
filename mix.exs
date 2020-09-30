defmodule Opalix.MixProject do
  use Mix.Project

  def project do
    [
      app: :opalix,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Opalix.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.4.0", runtime: false, only: [:dev, :test]},
      {:jason, "~> 1.2.1"},
      {:mint, "~> 1.1.0"},
      {:connection, "~> 1.0.4"}
    ]
  end

end
