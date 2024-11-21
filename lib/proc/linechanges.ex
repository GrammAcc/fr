defmodule Fr.Proc.Linechanges do
  use Fr.Proc

  defp tmpfile() do
    tmpdir = Path.expand("~/.fr/temp/")
    :filelib.ensure_path(tmpdir)

    rand_id =
      :crypto.strong_rand_bytes(4)
      |> :erlang.phash2()
      |> to_string()

    tmpfilepath = tmpdir <> "/" <> rand_id
    File.touch(tmpfilepath)
    File.stream!(tmpfilepath, :line)
  end

  def collect(filepaths, find, replace) when is_list(filepaths) and is_binary(find) and is_binary(replace) do
    collected =
      filepaths
      |> Enum.map(fn filepath ->
        Task.async(fn ->
          collect_linechanges(filepath, find, replace)
        end)
      end)
      |> Task.await_many()
      |> Enum.flat_map(fn res -> res end)

    GenServer.call(__MODULE__, {:collect, collected})
  end

  def collect(filepaths, %Fr.Findtag{} = findtag) when is_list(filepaths) do
    collected =
      filepaths
      |> Enum.map(fn filepath ->
        Task.async(fn ->
          collect_linechanges(filepath, findtag.find, findtag.replace)
        end)
      end)
      |> Task.await_many()
      |> Enum.flat_map(fn res -> res end)

    GenServer.call(__MODULE__, {:collect, collected})
  end

  def reset() do
    GenServer.call(__MODULE__, :reset)
  end

  def remove(optno) when is_integer(optno), do: GenServer.call(__MODULE__, {:remove, optno})

  def remove(optrange), do: GenServer.call(__MODULE__, {:remove, optrange})

  defp remove_fr_comment(%Fr.Findtag{} = findtag) do
    tmp = tmpfile()

    file = File.stream!(findtag.fp, :line)

    file
    |> Stream.filter(fn line -> !(line == findtag.fullline) end)
    |> Stream.into(tmp)
    |> Stream.run()

    tmp
    |> Stream.into(file)
    |> Stream.run()

    File.rm!(tmp.path)
  end

  def execute() do
    filechanges()
    |> Enum.map(fn {fp, artifacts} ->
      Task.async(fn ->
        linechanges =
          Enum.group_by(
            artifacts,
            fn {linechange, _optno} -> linechange.lineno end,
            fn {linechange, _optno} -> linechange end
          )

        IO.puts("Writing #{fp}...")

        tmp = tmpfile()
        file = File.stream!(fp, :line)

        file
        |> Stream.with_index(1)
        |> Stream.map(fn {line, lineno} ->
          case Map.get(linechanges, lineno, :not_found) do
            :not_found ->
              line

            [linechange] ->
              linechange.new
          end
        end)
        |> Stream.into(tmp)
        |> Stream.run()

        tmp
        |> Stream.into(file)
        |> Stream.run()

        File.rm!(tmp.path)
      end)
    end)
    |> Task.await_many()
  end

  def execute(%Fr.Findtag{} = findtag) do
    execute()
    remove_fr_comment(findtag)
  end

  def filechanges() do
    map =
      Enum.group_by(artifacts(), fn artifact ->
        {linechange, _optno} = artifact
        linechange.fp
      end)

    Enum.zip(Map.keys(map), Map.values(map))
    |> Enum.sort(fn a, b ->
      first_idx =
        elem(a, 1)
        |> List.first()
        |> elem(1)

      second_idx =
        elem(b, 1)
        |> List.first()
        |> elem(1)

      first_idx <= second_idx
    end)
  end

  @spec collect_linechanges(binary(), binary(), binary()) :: [Fr.Linechange.t()]
  def collect_linechanges(filepath, find, replace) do
    File.stream!(filepath, :line)
    |> Stream.with_index(1)
    |> Stream.filter(fn {line, _lineno} -> String.contains?(line, find) and !Fr.is_fr_comment?(line) end)
    |> Stream.map(fn {line, lineno} ->
      new_line = String.replace(line, find, replace)
      %Fr.Linechange{old: line, new: new_line, fp: filepath, lineno: lineno}
    end)
  end
end
