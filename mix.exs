defmodule ExLimiter.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ex_limiter,
      version: @version,
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      elixirc_paths: elixirc_paths(Mix.env),
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs() do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: "https://github.com/Frameio/ex_limiter"
    ]
  end

  defp deps do
    [
      {:memcachir, git: "https://github.com/Frameio/memcachir.git"},
      {:plug, "~> 1.4"},
    ]
  end

  defp description() do
    "Token bucket rate limiter written in elixir with configurable backends"
  end

  defp package() do
    [
      maintainers: ["Michael Guarino"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/Frameio/ex_limiter"}
    ]
  end
end