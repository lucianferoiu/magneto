defmodule Magneto.Mixfile do
  use Mix.Project

  def project do
    [app: :magneto,
     version: "0.1.1",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,

     # Hex
     description: description(),
     package: package(),

     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :timex, :httpoison, :ex_aws]]
  end

  defp description do
    """
    A DSL for Amazon DynamoDB
    """
  end

  defp deps do
    [{:poison, "~> 2.0"},
    {:httpoison, "~> 0.9.0"},
    {:timex, "~> 3.0"},
    {:ex_aws, "~> 1.0.0-beta3"}]
  end

  defp package do
    [name: :magneto,
     maintainers: ["Lucian Feroiu"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/lucianferoiu/magneto"},
     files: ~w(mix.exs README.md lib test)]
  end
end
