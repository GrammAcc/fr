defmodule Fr.Cli do
  @moduledoc """
  Find/replace for busy people

  usage examples:
    fr -e | --extensions <comma,separated> [<root_dir>...]
    fr -e | --extensions <comma,separated> [-i | --include <comma,separated>] [-x | --exclude <comma,separated>] [<root_dir>...]
    fr -e | --extensions <comma,separated> [-f | --find <string> -r | --replace <string>] [<root_dir>...]
    fr -e | --extensions <comma,separated> [--check] [<root_dir>...]
    fr -v | --version
    fr -h | --help

    positional args:
      root_dir:
      Top level directory to search within. No files above this directory will be changed.
      Can be specified multiple times to search within multiple directories.
      Defaults to $PWD if not provided.

    required switches:
      -e | --extensions:
        Comma-separated list of file extensions to search.

        Example: -e ex,py,json

    optional switches:
      -i | --include:
        Comma-separated list of additional files to include in the search.

        This can be used to match files that do not use an extension, or to include specific
        files that use a different extension than was specified with the -e switch.

        Supports basic globbing patterns such as 'src/*.py' and '**/*.spec'. However, the
        globbing semantics are handled by Elixir, so the shell's globbing settings will not
        be respected. Dotfiles are included as if `shopt -s dotglob` was set in bash, but special
        files `.` and `..` are not included. See: https://hexdocs.pm/elixir/Path.html#wildcard/2 for
        all globbing semantics.

        The argument must be wrapped in quotes if it contains a glob pattern.
        E.g. fr -x '.env,scripts/*.ex', not fr -x .env,scripts/*.ex

        Including directories is not supported as it is ambiguous which files inside the directory should
        be included. If you need to search within more than one directory, pass the <root_dir> positional
        argument multiple times.

        Example: -i 'Caddyfile,Dockerfile,submodule/src/*,**/.env'

      -x | --exclude:
        Comma-separated list of file and directory names to exclude from the search.

        This can be used to exclude vendor and deps directories or to exclude specific
        files or directories that would otherwise be matched based on the -e switch that
        was provided.

        Supports the same globbing patterns as the -i switch, but also excludes directory
        contents recursively since the meaning of excluding a directory is unambiguous.
        The quoting rules are the same as the -i switch as well.

        Example: -x 'deps,node_modules,.venv,**/docs'

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

      -v | --version:
        List version information and exit.

      -h | --help:
        Show this message and exit.
  """

  alias Fr.Cli.Prompt

  @version "fr v#{Fr.MixProject.version()} - elixir: #{System.version()}, otp: #{System.otp_release()}"

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

  defp parse_argv({options, [_ | _] = root_dirs}) do
    %Argv{options: Enum.into(options, %{}), args: %{root_dirs: root_dirs}}
  end

  defp parse_argv({options, []}) do
    {:ok, root_dir} = File.cwd()
    %Argv{options: Enum.into(options, %{}), args: %{root_dir: root_dir}}
  end

  defp validate_root_dirs(%Argv{} = argv) do
    expanded_dirs = Enum.map(argv.args.root_dirs, fn root_dir -> Path.expand(root_dir) end)

    if Enum.all?(expanded_dirs, fn expanded_dir -> File.dir?(expanded_dir) end) do
      %Argv{argv | args: %{argv.args | root_dirs: expanded_dirs}}
    else
      errs =
        expanded_dirs
        |> Enum.filter(fn expanded_dir -> !File.dir?(expanded_dir) end)
        |> Enum.map(fn err_dir -> "Error: '#{err_dir}' is not a directory" end)
        |> Enum.join("\n")

      break(1, errs)
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
        aliases: [e: :extensions, i: :include, x: :exclude, f: :find, r: :replace, h: :help, v: :version],
        strict: [
          extensions: :string,
          include: :string,
          exclude: :string,
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
      |> validate_root_dirs()
      |> parse_required(:extensions)
      |> parse_to_list(:extensions)
      |> parse_optional(:include)
      |> parse_to_list(:include)
      |> parse_optional(:exclude)
      |> parse_to_list(:exclude)
      |> parse_optional(:find)
      |> parse_optional(:replace)
      |> parse_optional(:check)

    root_dirs = parsed_argv.args.root_dirs
    extensions = parsed_argv.options.extensions
    include = parsed_argv.options.include
    exclude = parsed_argv.options.exclude
    find = parsed_argv.options.find
    replace = parsed_argv.options.replace
    check = parsed_argv.options.check

    case Fr.collect_filepaths(root_dirs, extensions, include, exclude) do
      {:error, msgs} ->
        err_msg = Enum.reduce(msgs, fn msg, acc -> acc <> "\n" <> msg end)
        break(1, err_msg)

      {:ok, filepaths} ->
        if notnil(check) do
          Fr.Proc.Findtags.collect(filepaths)

          case Fr.Proc.Findtags.artifacts() do
            [] ->
              break(0, "Nothing found")

            artifacts ->
              Prompt.print_artifacts(artifacts)
              break(1)
          end
        end

        if notnil(find) and notnil(replace) do
          Fr.Proc.Linechanges.collect(filepaths, find, replace)
          Prompt.linechange_prompt()
        else
          with {:ok, findtag} <-
                 Fr.Proc.Findtags.collect(filepaths)
                 |> Prompt.findtag_prompt() do
            Fr.Proc.Linechanges.collect(filepaths, findtag)
            Prompt.linechange_prompt(findtag)
          end
        end
    end
  end
end
