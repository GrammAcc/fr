defmodule Fr.Proc do
  defmodule State do
    @moduledoc false

    defstruct collected: [], removed: [], artifacts: [], selected: nil

    @typep ft_artifact :: {Fr.Findtag.t(), pos_integer()}
    @typep lc_artifact :: {Fr.Linechange.t(), pos_integer()}
    @typep artifact :: ft_artifact() | lc_artifact()
    @typep artifact_list :: [ft_artifact()] | [lc_artifact()]

    @type t :: %__MODULE__{
            collected: [Fr.Findtag.t()] | [Fr.Linechange.t()],
            artifacts: artifact_list(),
            removed: artifact_list(),
            selected: artifact()
          }
  end

  defmacro __using__(_opts) do
    quote do
      use GenServer

      def artifacts() do
        GenServer.call(__MODULE__, {:get, :artifacts})
      end

      def removed() do
        GenServer.call(__MODULE__, {:get, :removed})
      end

      def selected() do
        GenServer.call(__MODULE__, {:get, :selected})
      end

      def select(artifact_no) when is_integer(artifact_no) do
        GenServer.call(__MODULE__, {:select, artifact_no})
      end

      def start_link(_opts) do
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
      end

      @impl true
      def init(_init_arg) do
        {:ok, %State{}}
      end

      @impl true
      def handle_call({:get, :artifacts}, _from, %State{} = state) do
        {:reply, state.artifacts, state}
      end

      @impl true
      def handle_call({:get, :removed}, _from, %State{} = state) do
        {:reply, state.removed, state}
      end

      @impl true
      def handle_call({:get, :selected}, _from, %State{} = state) do
        {:reply, state.selected, state}
      end

      @impl true
      def handle_call({:select, artifact_no}, _from, %State{} = state) when is_integer(artifact_no) do
        new_selected =
          state.artifacts
          |> Enum.at(artifact_no - 1)
          |> elem(0)

        new_state = %State{state | selected: new_selected}
        {:reply, new_state.selected, new_state}
      end

      @impl true
      def handle_call({:remove, artifact_no}, _from, %State{} = state)
          when is_integer(artifact_no) do
        new_artifacts =
          state.artifacts
          |> Enum.filter(fn {_, optno} -> optno != artifact_no end)

        new_removed = [
          state.artifacts |> Enum.filter(fn {_, optno} -> optno == artifact_no end)
          | state.removed
        ]

        new_state = %State{state | artifacts: new_artifacts, removed: new_removed}
        {:reply, new_artifacts, new_state}
      end

      @impl true
      def handle_call({:remove, artifact_range}, _from, %State{} = state) do
        new_artifacts =
          state.artifacts
          |> Enum.filter(fn {_, optno} -> optno not in artifact_range end)

        new_removed = [
          state.artifacts |> Enum.filter(fn {_, optno} -> optno in artifact_range end)
          | state.removed
        ]

        new_state = %State{state | artifacts: new_artifacts, removed: new_removed}
        {:reply, new_artifacts, new_state}
      end

      @impl true
      def handle_call({:collect, collected}, _from, %State{} = _state) do
        artifacts =
          collected
          |> Enum.with_index(1)

        new_state = %State{collected: collected, artifacts: artifacts}
        {:reply, new_state.artifacts, new_state}
      end

      @impl true
      def handle_call(:reset, _from, %State{} = state) do
        artifacts =
          state.collected
          |> Enum.with_index(1)

        new_state = %State{state | artifacts: artifacts, removed: []}
        {:reply, new_state.artifacts, new_state}
      end

      defoverridable init: 1
    end
  end
end
