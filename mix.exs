defmodule Metr.MixProject do
  use Mix.Project

  def project do
    [
      app: :metr,
      version: "0.14.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: Metr.Modules.CLI],
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
      {:trail, [path: "../trail"]},
    ]
  end
end
