defmodule Fr do
  @moduledoc """
  The top level module for fr.
  """

  defmodule Filepaths do
    @moduledoc false
    defstruct filepaths: [], errors: []
  end

  @fr_label "[[fr]]"

  @spec is_fr_comment?(binary()) :: boolean()
  def is_fr_comment?(line) when is_binary(line), do: String.split(line, @fr_label) |> Enum.count() == 3

  @spec parse_fr_comment(binary()) :: {binary(), binary(), binary()}
  def parse_fr_comment(line) when is_binary(line) do
    String.split(line, @fr_label)
    |> Enum.at(1)
    |> String.split("::")
  end

  defp parse_paths([]), do: []

  defp parse_paths([_ | _] = paths) do
    Enum.flat_map(paths, fn path -> Path.wildcard(path, match_dot: true) end)
  end

  defp expand_paths([]), do: []
  defp expand_paths([_ | _] = paths), do: Enum.map(paths, fn maybe_rel -> Path.expand(maybe_rel) end)

  defp parse_filepaths_from_dirs([_ | _] = dir_paths, [_ | _] = extensions) do
    Enum.flat_map(dir_paths, fn dir_path ->
      Enum.map(extensions, fn ft -> dir_path <> "/**/*." <> ft end)
    end)
    |> parse_paths()
    |> Enum.flat_map(fn fp ->
      if File.dir?(fp) do
        parse_filepaths_from_dirs([fp], extensions)
      else
        [fp]
      end
    end)
    |> expand_paths()
    |> Enum.filter(fn path -> !Enum.member?(dir_paths, path) end)
  end

  defp parse_filepaths([_ | _] = dir_paths, [_ | _] = extensions) do
    %Filepaths{filepaths: parse_filepaths_from_dirs(dir_paths, extensions)}
  end

  @spec parse_file_exists_errors([binary()]) :: [binary()]
  defp parse_file_exists_errors(filepaths) do
    Enum.filter(filepaths, fn path -> !File.exists?(path) end)
    |> Enum.map(fn path -> "Error: file '#{path}' does not exist." end)
  end

  @spec parse_maybe_globbed_paths([binary()]) :: [binary()]
  defp parse_maybe_globbed_paths(pathstrings) do
    {globs, explicit} =
      case Enum.group_by(pathstrings, fn el ->
             if el =~ "*" do
               :globs
             else
               :explicit
             end
           end) do
        %{globs: globs, explicit: explicit} ->
          {globs, explicit}

        %{globs: globs} ->
          {globs, []}

        %{explicit: explicit} ->
          {[], explicit}
      end

    parse_paths(globs) ++ explicit
  end

  defp include_paths(%Filepaths{} = paths, nil = _include), do: paths
  defp include_paths(%Filepaths{} = paths, [] = _include), do: paths

  defp include_paths(%Filepaths{} = paths, [_ | _] = include) do
    parsed_paths = parse_maybe_globbed_paths(include)
    file_errors = parse_file_exists_errors(parsed_paths)

    dir_errors =
      Enum.filter(parsed_paths, fn path -> File.dir?(path) end)
      |> Enum.map(fn path -> "Error: Invalid value for '--include'. #{path} is a directory." end)

    parsed_errors = file_errors ++ dir_errors

    case parsed_errors do
      [] -> %Filepaths{paths | filepaths: paths.filepaths ++ expand_paths(parsed_paths)}
      errors -> %Filepaths{paths | errors: paths.errors ++ errors}
    end
  end

  defp exclude_paths(%Filepaths{} = paths, nil = _exclude), do: paths
  defp exclude_paths(%Filepaths{} = paths, [] = _exclude), do: paths

  defp exclude_paths(%Filepaths{} = paths, [_ | _] = exclude) do
    parsed_paths =
      parse_maybe_globbed_paths(exclude)
      |> Enum.flat_map(fn path ->
        if File.dir?(path) do
          parse_paths([path <> "/*"])
        else
          [path]
        end
      end)

    errors = parse_file_exists_errors(parsed_paths)

    new_paths =
      paths.filepaths
      |> Enum.filter(fn path ->
        parsed_paths
        |> expand_paths()
        |> Enum.all?(fn to_exclude -> path != to_exclude end)
      end)

    %Filepaths{paths | filepaths: new_paths, errors: paths.errors ++ errors}
  end

  defp check_filepaths(%Filepaths{filepaths: []}), do: {:ok, []}

  defp check_filepaths(%Filepaths{} = paths) do
    # Runtime assertion.
    Enum.each(paths.filepaths, fn path ->
      if File.dir?(path),
        do: raise(%RuntimeError{message: "Assertion failure: directory #{path} collected as file"})
    end)

    case paths.errors do
      [] -> {:ok, paths.filepaths}
      _ -> {:error, paths.errors}
    end
  end

  @spec collect_filepaths([Path.t()], [String.t()], [String.t()] | nil, [String.t()] | nil) :: [binary()]
  def collect_filepaths(root_dirs, extensions, include, exclude) do
    parse_filepaths(root_dirs, extensions)
    |> include_paths(include)
    |> exclude_paths(exclude)
    |> (&%Filepaths{&1 | filepaths: Enum.uniq(&1.filepaths)}).()
    |> check_filepaths()
  end
end
