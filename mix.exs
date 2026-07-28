defmodule ExBoxPacker.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/andypho/ex_box_packer"

  def project do
    [
      app: :ex_box_packer,
      version: @version,
      elixir: "~> 1.20",
      compilers: [:boundary] ++ Mix.compilers(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "ExBoxPacker",
      description:
        "A faithful Elixir port of the BoxPacker 3D bin-packing / box-selection library.",
      package: package(),
      docs: docs(),
      source_url: @source_url,
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:boundary, "~> 0.10", runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:plug, "~> 1.15", optional: true},
      {:stream_data, "~> 1.1", only: [:dev, :test]}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      files: ["lib", "priv", "mix.exs", "README.md", "LICENSE", "CHANGELOG.md", ".formatter.exs"],
      links: %{
        "GitHub" => @source_url,
        "Original BoxPacker (PHP)" => "https://github.com/dvdoug/BoxPacker"
      }
    ]
  end

  defp docs do
    [
      main: "ExBoxPacker",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      groups_for_modules: [
        Packing: [ExBoxPacker.Packer, ExBoxPacker.Engine.VolumePacker],
        "Items & Boxes": [
          ExBoxPacker.Item,
          ExBoxPacker.Box,
          ExBoxPacker.SimpleItem,
          ExBoxPacker.SimpleBox,
          ExBoxPacker.Rotation
        ],
        Results: [
          ExBoxPacker.Result.PackedBox,
          ExBoxPacker.Result.PackedBoxList,
          ExBoxPacker.Result.PackedItem,
          ExBoxPacker.Result.PackedItemList
        ],
        Sorting: [
          ExBoxPacker.Sorting.ItemSorter,
          ExBoxPacker.Sorting.DefaultItemSorter,
          ExBoxPacker.Sorting.BoxSorter,
          ExBoxPacker.Sorting.DefaultBoxSorter,
          ExBoxPacker.Sorting.PackedBoxSorter,
          ExBoxPacker.Sorting.DefaultPackedBoxSorter
        ],
        Errors: [ExBoxPacker.NoBoxesAvailableError]
      ]
    ]
  end
end
