defmodule Daftka.MixProject do
  use Mix.Project

  def project do
    [
      app: :daftka,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      preferred_cli_env: [
        credo: :test,
        dialyzer: :test,
        docs: :dev,
        ci: :test
      ],
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix]
      ],
      docs: [
        main: "readme",
        extras: ["README.md", "PLAN.md", "TODO.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Daftka.Application, []},
      extra_applications: extra_apps(Mix.env())
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      ci: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict",
        "dialyzer",
        "test",
        # ensure docs run in dev env where ex_doc is available
        "cmd MIX_ENV=dev mix docs"
      ]
    ]
  end

  # Development-only extras so IEx can launch the Observer GUI.
  defp extra_apps(:dev), do: [:logger, :wx, :observer]
  defp extra_apps(_env), do: [:logger]
end
