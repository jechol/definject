defmodule Definject.MixProject do
  use Mix.Project

  @version "1.1.6"

  def project do
    [
      app: :definject,
      version: @version,
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      package: package(),
      description: "Unobtrusive Dependency Injector for Elixir",
      source_url: "https://github.com/definject/definject",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.21.0", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/definject/definject"},
      maintainers: ["Jechol Lee(mr.jechol@gmail.com)"]
    ]
  end

  defp docs() do
    [
      main: "readme",
      name: "definject",
      canonical: "http://hexdocs.pm/definject",
      source_url: "https://github.com/definject/definject",
      extras: [
        "README.md"
      ]
    ]
  end
end
