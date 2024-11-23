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

  defp parse_filepaths(dir_path, [_ | _] = extensions) do
    Enum.flat_map(extensions, fn ft ->
      Path.wildcard(dir_path <> "/**/*." <> ft, match_dot: true)
    end)
  end

  defp parse_paths([_ | _] = paths, [_ | _] = extensions) do
    paths
    |> Enum.flat_map(fn path ->
      if File.dir?(path) do
        parse_filepaths(path, extensions)
      else
        [path]
      end
    end)
  end

  defp include_paths(filepaths, nil, _extensions) when is_list(filepaths), do: filepaths

  defp include_paths(filepaths, [_ | _] = include, [_ | _] = extensions) when is_list(filepaths) do
    filepaths ++ parse_paths(include, extensions)
  end

  defp exclude_paths([_ | _] = filepaths, [_ | _] = exclude) do
    filepaths
    |> Enum.filter(fn path ->
      Enum.all?(exclude, fn to_exclude -> path != to_exclude end)
    end)
  end

  defp exclude_paths(filepaths, nil) when is_list(filepaths), do: filepaths

  defp check_filepaths([]), do: []

  defp check_filepaths([_ | _] = filepaths) do
    errors = Enum.filter(filepaths, fn path -> !File.exists?(path) end)

    case errors do
      [] -> {:ok, filepaths}
      _ -> {:error, Enum.map(errors, fn path -> "Error: file '#{path}' does not exist." end)}
    end
  end

  @spec collect_filepaths(Path.t(), [String.t()], [String.t()] | nil, [String.t()] | nil) :: [binary()]
  def collect_filepaths(root_dir, extensions, include, exclude) do
    parse_filepaths(root_dir, extensions)
    |> include_paths(include, extensions)
    |> exclude_paths(exclude)
    |> check_filepaths()
  end
end
