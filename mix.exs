defmodule Autofunctions.MixProject do
  use Mix.Project

  def project do
    [
      app: :autofunctions,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(),
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
      {:req, "~> 0.3.9"},
      {:kino, "~> 0.9.4"}
    ]
  end

  defp elixirc_paths, do: elixirc_paths(Mix.env())
  defp elixirc_paths(_), do: ["lib"]
end
