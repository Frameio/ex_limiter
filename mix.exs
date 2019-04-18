defmodule ExLimiter.Mixfile do
  use Mix.Project

  @version "1.2.1"

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
      extra_applications: [:logger],
      applications: []
    ]
  end

  defp deps do
    [
      {:memcachir, "~> 3.2.0"},
      {:plug, "~> 1.4"},
      {:ex_doc, "~> 0.19", only: :dev}
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
