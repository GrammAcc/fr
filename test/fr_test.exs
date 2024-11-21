defmodule FrTest do
  use ExUnit.Case
  doctest Fr

  def seed_files(root_dir) do
    File.cp_r!(root_dir <> "/seed", root_dir <> "/input")
  end

  defp read(root_dir, ext, :expected) do
    File.stream!(root_dir <> "/expected/one." <> ext, :line)
    |> Enum.to_list()
  end

  defp read(root_dir, ext, :input) do
    File.stream!(root_dir <> "/input/one." <> ext, :line)
    |> Enum.to_list()
  end

  defp read(root_dir, ext, :seed) do
    File.stream!(root_dir <> "/seed/one." <> ext, :line)
    |> Enum.to_list()
  end

  def read(root_dir, ext), do: {read(root_dir, ext, :input), read(root_dir, ext, :expected)}

  test "tempfiles are cleaned up" do
    root_dir = "test/integration/basic_usage"
    seed_files(root_dir)
    filepaths = Fr.collect_filepaths(root_dir <> "/input", ["ts", "json"], nil)

    filepaths
    |> Fr.Proc.Findtags.collect()

    findtag = Fr.Proc.Findtags.select(2)

    filepaths
    |> Fr.Proc.Linechanges.collect(findtag)

    Fr.Proc.Linechanges.execute(findtag)
    temppath = Path.expand("~/.fr/temp")
    assert File.ls!(temppath) == []
    {sut_json, expected_json} = read(root_dir, "json")
    {sut_ts, expected_ts} = read(root_dir, "ts")
    assert expected_json == sut_json
    assert expected_ts == sut_ts
  end

  test "findreplace-basic_usage" do
    root_dir = "test/integration/basic_usage"
    seed_files(root_dir)
    filepaths = Fr.collect_filepaths(root_dir <> "/input", ["ts", "json"], nil)

    filepaths
    |> Fr.Proc.Findtags.collect()

    findtag = Fr.Proc.Findtags.select(2)

    filepaths
    |> Fr.Proc.Linechanges.collect(findtag)

    Fr.Proc.Linechanges.execute(findtag)
    {sut_json, expected_json} = read(root_dir, "json")
    {sut_ts, expected_ts} = read(root_dir, "ts")
    assert expected_json == sut_json
    assert expected_ts == sut_ts
  end

  test "findreplace-comment_above_target_line" do
    root_dir = "test/integration/comment_relative_location/above_line"
    seed_files(root_dir)

    filepaths = Fr.collect_filepaths(root_dir <> "/input", ["ex"], nil)

    filepaths
    |> Fr.Proc.Findtags.collect()

    findtag = Fr.Proc.Findtags.select(1)

    filepaths
    |> Fr.Proc.Linechanges.collect(findtag)

    Fr.Proc.Linechanges.execute(findtag)

    {sut, expected} = read(root_dir, "ex")
    assert sut == expected
  end

  test "findreplace-comment_below_target_line" do
    root_dir = "test/integration/comment_relative_location/below_line"
    seed_files(root_dir)

    filepaths = Fr.collect_filepaths(root_dir <> "/input", ["ex"], nil)

    filepaths
    |> Fr.Proc.Findtags.collect()

    findtag = Fr.Proc.Findtags.select(1)

    filepaths
    |> Fr.Proc.Linechanges.collect(findtag)

    Fr.Proc.Linechanges.execute(findtag)

    {sut, expected} = read(root_dir, "ex")
    assert sut == expected
  end
end
