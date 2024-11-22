defmodule Fr.Cli do
  @moduledoc """
  Find/replace for busy people

  usage examples:
    fr -e | --extensions <comma,separated> [<root_dir>]
    fr -e | --extensions <comma,separated> [-x | --extra-files <comma,separated>] [<root_dir>]
    fr -e | --extensions <comma,separated> [-f | --find <string> -r | --replace <string>] [<root_dir>]
    fr -e | --extensions <comma,separated> [-x | --extra-files <comma,separated>] [--check] [<root_dir>]
    fr -h | --help

    positional args:
      root_dir:
      The top directory to search within. No files above this directory will be changed.
      Defaults to $PWD if not provided.

    required switches:
      -e | --extensions:
        Comma-separated list of file extensions to search.
        Example: -e ex,py,json

    optional switches:
      -x | --extra-files:
        Comma-separated list of additional filenames to include in the search.
        This list is matched exactly, so it can be used to match files that do not
        use an extension, or to include specific files that use a different extension
        than specified with the -e option.
        Example: -x Caddyfile,Dockerfile

      -f | --find:
        String to search for. If provided, then findtags are not searched.
        Has no effect if specified without --replace.

      -r | --replace:
        String to replace with when searching without findtags.
        Has no effect if specified without --find.

    flags:
      --check:
        List all findtags in the matched files.
        Returns exit code 0 if no findtags are found, else 1.
        This can be used in a CI workflow to ensure no findtags are left in
        the source code.

      -h | --help:
        Show this message and exit.
  """

  alias Fr.Cli.Prompt

  @version "fr v0.1.0 - elixir: #{System.version()}, otp: #{System.otp_release()}"

  defmodule Argv do
    @moduledoc false
    defstruct options: %{}, args: %{}
  end

  defp notnil(arg), do: arg != nil

  defp break(status) when is_integer(status) do
    System.stop(status)
    Process.sleep(:infinity)
  end

  defp break(status, msg) when is_integer(status) and is_binary(msg) do
    IO.puts(msg)
    break(status)
  end

  defp parse_argv({options, [root_dir]}) do
    %Argv{options: Enum.into(options, %{}), args: %{root_dir: root_dir}}
  end

  defp parse_argv({options, []}) do
    {:ok, root_dir} = File.cwd()
    %Argv{options: Enum.into(options, %{}), args: %{root_dir: root_dir}}
  end

  defp validate_root_dir(%Argv{} = argv) do
    expanded = Path.expand(argv.args.root_dir)

    if File.dir?(expanded) do
      %Argv{argv | args: %{argv.args | root_dir: expanded}}
    else
      break(1, "#{argv.args.root_dir} is not a directory")
    end
  end

  defp parse_help(%Argv{} = argv) do
    case argv.options do
      %{help: true} ->
        break(0, @moduledoc)

      _ ->
        argv
    end
  end

  defp parse_version(%Argv{} = argv) do
    case argv.options do
      %{version: true} ->
        break(0, @version)

      _ ->
        argv
    end
  end

  defp parse_optional(%Argv{} = argv, opt) when is_atom(opt) do
    case Map.get(argv.options, opt, :not_found) do
      :not_found ->
        %Argv{argv | options: Map.put(argv.options, opt, nil)}

      _ ->
        argv
    end
  end

  defp parse_required(%Argv{} = argv, opt) when is_atom(opt) do
    case Map.get(argv.options, opt, :not_found) do
      :not_found ->
        break(1, "#{"--" <> String.replace(Atom.to_string(opt), "_", "-")} is required. Try fr --help")

      _ ->
        argv
    end
  end

  defp parse_to_list(%Argv{} = argv, key) when is_atom(key) do
    case Map.get(argv.options, key) do
      nil ->
        argv

      val ->
        new_value =
          val
          |> String.split(",", trim: true)

        new_options = %{argv.options | key => new_value}
        %Argv{argv | options: new_options}
    end
  end

  def main(argv) do
    parsed_argv =
      OptionParser.parse!(argv,
        aliases: [e: :extensions, x: :extra_files, f: :find, r: :replace, h: :help, v: :version],
        strict: [
          extensions: :string,
          extra_files: :string,
          find: :string,
          replace: :string,
          check: :boolean,
          help: :boolean,
          version: :boolean
        ]
      )
      |> parse_argv()
      |> parse_help()
      |> parse_version()
      |> validate_root_dir()
      |> parse_required(:extensions)
      |> parse_to_list(:extensions)
      |> parse_optional(:extra_files)
      |> parse_to_list(:extra_files)
      |> parse_optional(:find)
      |> parse_optional(:replace)
      |> parse_optional(:check)

    root_dir = parsed_argv.args.root_dir
    extensions = parsed_argv.options.extensions
    extra_files = parsed_argv.options.extra_files
    find = parsed_argv.options.find
    replace = parsed_argv.options.replace
    check = parsed_argv.options.check

    filepaths = Fr.collect_filepaths(root_dir, extensions, extra_files)

    if notnil(check) do
      Fr.Proc.Findtags.collect(filepaths)

      case Fr.Proc.Findtags.artifacts() do
        [] ->
          break(0, "Nothing found")

        artifacts ->
          Prompt.print_artifacts(artifacts, 0)
          break(1)
      end
    end

    if notnil(find) and notnil(replace) do
      Fr.Proc.Linechanges.collect(filepaths, find, replace)
      Prompt.linechange_prompt(0)
    else
      with {:ok, findtag} <-
             Fr.Proc.Findtags.collect(filepaths)
             |> Prompt.findtag_prompt(0) do
        Fr.Proc.Linechanges.collect(filepaths, findtag)
        Prompt.linechange_prompt(findtag, 0)
      end
    end
  end
end
