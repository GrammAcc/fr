defmodule Fr.Test.Integration do
  use ExUnit.Case
  doctest Fr

  defp seed_files(root_dir) do
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

  defp read(root_dir, ext), do: {read(root_dir, ext, :input), read(root_dir, ext, :expected)}

  test "tempfiles are cleaned up" do
    root_dir = "test/integration/basic_usage"
    seed_files(root_dir)
    {:ok, filepaths} = Fr.collect_filepaths([root_dir <> "/input"], ["ts", "json"], nil, nil)

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

  describe "execute_findreplace" do
    test "basic_usage" do
      root_dir = "test/integration/basic_usage"
      seed_files(root_dir)
      {:ok, filepaths} = Fr.collect_filepaths([root_dir <> "/input"], ["ts", "json"], nil, nil)

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

    test "comment_above_target_line" do
      root_dir = "test/integration/comment_relative_location/above_line"
      seed_files(root_dir)

      {:ok, filepaths} = Fr.collect_filepaths([root_dir <> "/input"], ["ex"], nil, nil)

      filepaths
      |> Fr.Proc.Findtags.collect()

      findtag = Fr.Proc.Findtags.select(1)

      filepaths
      |> Fr.Proc.Linechanges.collect(findtag)

      Fr.Proc.Linechanges.execute(findtag)

      {sut, expected} = read(root_dir, "ex")
      assert sut == expected
    end

    test "comment_below_target_line" do
      root_dir = "test/integration/comment_relative_location/below_line"
      seed_files(root_dir)

      {:ok, filepaths} = Fr.collect_filepaths([root_dir <> "/input"], ["ex"], nil, nil)

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

  describe "collect_filepaths" do
    @root_dir "test/integration/collect_filepaths"
    @ts_dir @root_dir <> "/ts"
    @expanded_ts_dir quote(do: Path.expand(@ts_dir))
    @ex_dir @root_dir <> "/ex"
    @expanded_ex_dir quote(do: Path.expand(@ex_dir))
    @extensions ["ts", "ex"]

    test "no-extra-flags" do
      expanded_ts_dir = unquote(@expanded_ts_dir)
      filepaths = Fr.collect_filepaths([@ts_dir], @extensions, nil, nil)
      expected = {:ok, [expanded_ts_dir <> "/one.ts", expanded_ts_dir <> "/two.ts"]}
      assert filepaths == expected
    end

    test "multiple-ts_dirs" do
      expanded_ts_dir = unquote(@expanded_ts_dir)
      filepaths = Fr.collect_filepaths([@ts_dir, @ex_dir], @extensions, nil, nil)

      expected =
        {:ok, [expanded_ts_dir <> "/one.ts", expanded_ts_dir <> "/two.ts", Path.expand(@ex_dir) <> "/one.ex"]}

      assert filepaths == expected
    end

    test "with-include" do
      expanded_ts_dir = unquote(@expanded_ts_dir)
      filepaths = Fr.collect_filepaths([@ts_dir], @extensions, [".gitignore"], nil)

      expected =
        {:ok, [expanded_ts_dir <> "/one.ts", expanded_ts_dir <> "/two.ts", Path.expand(".gitignore")]}

      assert filepaths == expected
    end

    test "include-non-existent-file-returns-error" do
      filepaths = Fr.collect_filepaths([@ts_dir], @extensions, ["one.json"], nil)
      expected = {:error, ["Error: file 'one.json' does not exist."]}
      assert filepaths == expected
    end

    test "include-matches-exact-path" do
      expanded_ts_dir = unquote(@expanded_ts_dir)
      filepaths = Fr.collect_filepaths([@ts_dir], @extensions, [@ts_dir <> "/one.json"], nil)

      expected =
        {:ok, [expanded_ts_dir <> "/one.ts", expanded_ts_dir <> "/two.ts", expanded_ts_dir <> "/one.json"]}

      assert filepaths == expected
    end

    test "include-dir-causes-err" do
      filepaths = Fr.collect_filepaths([@ts_dir], @extensions, [@ex_dir], nil)
      expected = {:error, ["Error: Invalid value for '--include'. #{@ex_dir} is a directory."]}
      assert filepaths == expected
    end

    test "include-glob" do
      expanded_ts_dir = unquote(@expanded_ts_dir)
      included = @root_dir <> "/**/*.ex"

      {:ok, filepaths} = Fr.collect_filepaths([@ts_dir], @extensions, [included], nil)

      expected_paths = [
        expanded_ts_dir <> "/one.ts",
        expanded_ts_dir <> "/two.ts",
        Path.expand(@ex_dir) <> "/one.ex"
      ]

      assert filepaths == expected_paths
    end

    test "with-exclude" do
      expanded_ts_dir = unquote(@expanded_ts_dir)
      filepaths = Fr.collect_filepaths([@ts_dir], @extensions, nil, [@ts_dir <> "/two.ts"])
      expected = {:ok, [expanded_ts_dir <> "/one.ts"]}
      assert filepaths == expected
    end

    test "exclude-non-existent-file-returns-error" do
      filepaths = Fr.collect_filepaths([@ts_dir], @extensions, nil, ["two.ts"])
      expected = {:error, ["Error: file 'two.ts' does not exist."]}
      assert filepaths == expected
    end

    test "exclude-glob" do
      expanded_ts_dir = unquote(@expanded_ts_dir)
      filepaths = Fr.collect_filepaths([@ts_dir], @extensions, nil, ["**/two.ts"])
      expected = {:ok, [expanded_ts_dir <> "/one.ts"]}
      assert filepaths == expected
    end

    test "exclude-dir" do
      expanded_ts_dir = unquote(@expanded_ts_dir)
      filepaths = Fr.collect_filepaths([@root_dir], ["ts", "ex", "json"], nil, [@ex_dir])

      expected =
        {:ok, [expanded_ts_dir <> "/one.ts", expanded_ts_dir <> "/two.ts", expanded_ts_dir <> "/one.json"]}

      assert filepaths == expected
    end

    test "with-include-and-exclude" do
      expanded_ts_dir = unquote(@expanded_ts_dir)
      filepaths = Fr.collect_filepaths([@ts_dir], @extensions, [".gitignore"], [@ts_dir <> "/two.ts"])
      expected = {:ok, [expanded_ts_dir <> "/one.ts", Path.expand(".gitignore")]}
      assert filepaths == expected
    end

    test "with-include-and-exclude-exclude-takes-priority" do
      expanded_ts_dir = unquote(@expanded_ts_dir)
      incl_excl = [@ts_dir <> "/two.ts"]
      filepaths = Fr.collect_filepaths([@ts_dir], @extensions, incl_excl, incl_excl)
      expected = {:ok, [expanded_ts_dir <> "/one.ts"]}
      assert filepaths == expected
    end
  end
end
