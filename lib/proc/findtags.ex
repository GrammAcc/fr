defmodule Fr.Proc.Findtags do
  use Fr.Proc

  alias Fr.Proc.State

  def collect(filepaths) do
    collected =
      filepaths
      |> Enum.map(fn fp ->
        Task.async(fn -> collect_findtags(fp) end)
      end)
      |> Task.await_many()
      |> Enum.flat_map(fn res -> res end)
      |> Enum.uniq()

    GenServer.call(__MODULE__, {:collect, collected})
  end

  def update_selected(%Fr.Findtag{} = findtag, :replace) do
    GenServer.call(__MODULE__, {:update_selected, findtag, :replace})
  end

  @impl true
  def handle_call({:update_selected, %Fr.Findtag{} = findtag, :replace}, _from, %State{} = state) do
    new_selected = %Fr.Findtag{state.selected | replace: findtag.replace}
    new_state = %State{state | selected: new_selected}
    {:reply, new_state.selected, new_state}
  end

  @spec collect_findtags(Path.t()) :: [Fr.Findtag.t()]
  defp collect_findtags(filepath) do
    File.stream!(filepath, :line)
    |> Stream.with_index(1)
    |> Stream.filter(fn {line, _lineno} -> Fr.is_fr_comment?(line) end)
    |> Stream.map(fn {line, lineno} ->
      case Fr.parse_fr_comment(line) do
        [desc, find, replace] ->
          %Fr.Findtag{
            description: desc,
            find: find,
            replace: replace,
            fp: filepath,
            lineno: lineno,
            fullline: line
          }

        [desc, find] ->
          %Fr.Findtag{
            description: desc,
            find: find,
            replace: :user_input,
            fp: filepath,
            lineno: lineno,
            fullline: line
          }
      end
    end)
  end
end
