defmodule Fr.Cli.Prompt do
  @findtag_help """
    Select which findtag you want to operate on.
    You will have a chance to review the individual lines that will be edited
    before executing the find/replace operation.

    Additional commands:
      'q': Quit the program.
      'h': Show this help message.
  """

  @linechange_help """
    The files and lines that will be edited will be printed to the console, and individual
    lines can be removed from the target set by typing '-optno' into the command prompt where
    'optno' is the number to the left of the change preview. A range can also be specified as
    '-optno-optno'.

    Additional commands:
      'e': Execute the find/replace operation.
        You will have a chance to review the full set of changes and cancel before final execution.
      'r': Reset the list of lines to edit.
        This can be used if a line that should be included is accidentally removed.
      'q': Quit the program.
      'h': Show this help message.
  """

  defp prompt(query) when is_binary(query) do
    IO.puts(query)

    IO.gets("fr--> ")
    |> String.trim_trailing("\n")
  end

  defp parse_replace(%Fr.Findtag{replace: :user_input} = findtag) do
    user_input = prompt("Replace #{findtag.find} with...")

    %Fr.Findtag{findtag | replace: user_input}
  end

  defp parse_replace(%Fr.Findtag{} = findtag) do
    findtag
  end

  defp print_artifact({%Fr.Linechange{} = linechange, optno}) do
    IO.puts(
      "    |__ #{optno}) line#{linechange.lineno}:\n        '#{String.trim_trailing(linechange.old, "\n")}'\n        |\n        V\n        '#{String.trim_trailing(linechange.new, "\n")}'"
    )
  end

  defp print_artifact({%Fr.Findtag{} = findtag, optno}) do
    to_replace =
      if findtag.replace == :user_input do
        "<input>"
      else
        findtag.replace
      end

    IO.puts("  #{optno}) Find - #{findtag.find}, Replace - #{to_replace}")
  end

  def print_artifacts([{_fp, [{%Fr.Linechange{}, _optno} | _]} | _] = artifacts) do
    Enum.each(artifacts, fn {filepath, linechanges} ->
      IO.puts("\n")
      IO.puts("  " <> filepath)
      Enum.each(linechanges, fn artifact -> print_artifact(artifact) end)
    end)

    IO.puts("\n")

    artifacts
  end

  def print_artifacts([{%Fr.Findtag{}, _optno} | _] = artifacts) do
    IO.puts("\n")
    Enum.each(artifacts, fn artifact -> print_artifact(artifact) end)
    IO.puts("\n")
    artifacts
  end

  def print_artifacts([]) do
    IO.puts("Nothing found")
  end

  defp cancel() do
    IO.puts("Cancelling...")
    {:cancelled, "Cancelled by user"}
  end

  defp print_help(:findtag) do
    IO.puts("\n")
    IO.puts(@findtag_help)
    IO.gets("<Enter> to continue...")
  end

  defp print_help(:linechange) do
    IO.puts("\n")
    IO.puts(@linechange_help)
    IO.gets("<Enter> to continue...")
  end

  defp input_error(user_input) when is_binary(user_input) do
    IO.puts("Invalid instruction #{user_input}")
  end

  @spec findtag_prompt([{Fr.Findtag.t(), pos_integer()}]) :: {:ok, Fr.Findtag.t()} | {:cancelled, binary()}
  def findtag_prompt(artifacts) do
    print_artifacts(artifacts)

    user_input =
      prompt("Enter the number of the findtag you want to use. 'q' to quit, 'h' for help...")

    case Integer.parse(user_input) do
      :error ->
        case String.downcase(user_input) do
          "q" ->
            cancel()

          "h" ->
            print_help(:findtag)
            findtag_prompt(artifacts)

          _ ->
            input_error(user_input)
            findtag_prompt(artifacts)
        end

      {optno, _} ->
        if optno > length(artifacts) or optno < 1 do
          input_error(user_input)
          findtag_prompt(artifacts)
        else
          parsed_findtag =
            Fr.Proc.Findtags.select(optno)
            |> parse_replace()
            |> Fr.Proc.Findtags.update_selected(:replace)

          {:ok, parsed_findtag}
        end
    end
  end

  def confirm_prompt() do
    IO.puts("The following lines will be modified...")

    Fr.Proc.Linechanges.filechanges()
    |> print_artifacts()

    to_continue = prompt("Continue? y/N")

    if String.downcase(String.trim(to_continue)) == "y" do
      Fr.Proc.Linechanges.execute()
      :ok
    else
      :cancelled
    end
  end

  def confirm_prompt(%Fr.Findtag{} = findtag) do
    IO.puts("The following lines will be modified...")

    Fr.Proc.Linechanges.filechanges()
    |> print_artifacts()

    to_continue = prompt("Continue? y/N")

    if String.downcase(String.trim(to_continue)) == "y" do
      Fr.Proc.Linechanges.execute(findtag)
      :ok
    else
      :cancelled
    end
  end

  def linechange_prompt() do
    Fr.Proc.Linechanges.filechanges()
    |> print_artifacts()

    user_input =
      prompt(
        "'-<OPTNO>[-<OPTNO>] to remove line(s) from replace set, 'e' to execute find/replace, 'q' to quit, 'r' to reset replace set, 'h' for help."
      )

    split_input = String.split(user_input, "-")

    case length(split_input) do
      1 ->
        case String.downcase(user_input) do
          "e" ->
            confirm_prompt()

          "q" ->
            cancel()

          "r" ->
            Fr.Proc.Linechanges.reset()
            linechange_prompt()

          "h" ->
            print_help(:linechange)
            linechange_prompt()
        end

      2 ->
        IO.puts("len was two")

        case Integer.parse(Enum.at(split_input, 1)) do
          {num, _} ->
            Fr.Proc.Linechanges.remove(num)
            linechange_prompt()

          :error ->
            input_error(user_input)
            linechange_prompt()
        end

      3 ->
        [_, open, close] = split_input
        {open, _} = Integer.parse(open)
        {close, _} = Integer.parse(close)
        Fr.Proc.Linechanges.remove(open..close)
        linechange_prompt()

      _ ->
        input_error(user_input)
        linechange_prompt()
    end
  end

  @spec linechange_prompt(Fr.Findtag.t()) :: :ok | :cancelled
  def linechange_prompt(%Fr.Findtag{} = findtag) do
    Fr.Proc.Linechanges.filechanges()
    |> print_artifacts()

    user_input =
      prompt(
        "'-<OPTNO>[-<OPTNO>] to remove line(s) from replace set, 'e' to execute find/replace, 'q' to quit, 'r' to reset replace set, 'h' for help."
      )

    split_input = String.split(user_input, "-")

    case length(split_input) do
      1 ->
        case String.downcase(user_input) do
          "e" ->
            confirm_prompt(findtag)

          "q" ->
            cancel()

          "r" ->
            Fr.Proc.Linechanges.reset()
            linechange_prompt(findtag)

          "h" ->
            print_help(:linechange)
            linechange_prompt(findtag)
        end

      2 ->
        IO.puts("len was two")

        case Integer.parse(Enum.at(split_input, 1)) do
          {num, _} ->
            Fr.Proc.Linechanges.remove(num)
            linechange_prompt(findtag)

          :error ->
            input_error(user_input)
            linechange_prompt(findtag)
        end

      3 ->
        [_, open, close] = split_input
        {open, _} = Integer.parse(open)
        {close, _} = Integer.parse(close)
        Fr.Proc.Linechanges.remove(open..close)
        linechange_prompt(findtag)

      _ ->
        input_error(user_input)
        linechange_prompt(findtag)
    end
  end
end
