defmodule Fr do
  @moduledoc """
  The top level module for fr.
  """

  @fr_label "[[fr]]"

  @spec is_fr_comment?(binary()) :: boolean()
  def is_fr_comment?(line) when is_binary(line), do: String.split(line, @fr_label) |> Enum.count() == 3

  @spec parse_fr_comment(binary()) :: {binary(), binary(), binary()}
  def parse_fr_comment(line) when is_binary(line) do
    String.split(line, @fr_label)
    |> Enum.at(1)
    |> String.split("::")
  end

  @spec collect_filepaths(Path.t(), [String.t()], nil) :: [binary()]
  def collect_filepaths(root_dir, extensions, nil) do
    Enum.flat_map(extensions, fn ft ->
      Path.wildcard(root_dir <> "/**/*." <> ft, match_dot: true)
    end)
  end

  @spec collect_filepaths(Path.t(), [String.t()], [String.t()]) :: [binary()]
  def collect_filepaths(root_dir, extensions, [_ | _] = extra_files) do
    Enum.flat_map(extensions, fn ft ->
      Path.wildcard(root_dir <> "/**/*." <> ft, match_dot: true)
    end) ++ extra_files
  end
end
