defmodule Fr.MixProject do
  use Mix.Project

  def version(), do: "0.2.0"

  def project do
    [
      app: :fr,
      version: version(),
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: Fr.Cli],
      name: "fr",
      source_url: "https://github.com/GrammAcc/fr",
      homepage_url: "https://github.com/GrammAcc/fr",
      docs: [
        main: "Fr",
        api_reference: true,
        extras: ["README.md"],
        authors: ["GrammAcc"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Fr.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.25.0", only: [:dev]}
    ]
  end
end
