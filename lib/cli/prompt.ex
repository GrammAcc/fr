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

  @prompt_height 20

  defp normalize_offset(offset) when is_integer(offset) do
    if offset < 0 do
      0
    else
      offset
    end
  end

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

  def print_artifacts([{_fp, [{%Fr.Linechange{}, _optno} | _]} | _] = artifacts, offset) do
    norm_offset = normalize_offset(offset)

    output_string =
      artifacts
      |> windowed_output(norm_offset)
      |> Enum.join("\n")

    IO.puts("\n" <> output_string <> "\n")

    artifacts
  end

  def print_artifacts([{%Fr.Findtag{}, _optno} | _] = artifacts, offset) do
    norm_offset = normalize_offset(offset)

    output_string =
      artifacts
      |> windowed_output(norm_offset)
      |> Enum.join("\n")

    IO.puts("\n" <> output_string <> "\n")
    artifacts
  end

  def print_artifacts([], _offset) do
    IO.puts("Nothing found")
    []
  end

  @spec format_output({Fr.Linechange.t(), pos_integer()}) :: binary()
  defp format_output({%Fr.Linechange{} = linechange, optno}) do
    "    " <>
      "|__ #{optno}) line#{linechange.lineno}:\n" <>
      "        " <>
      "'#{String.trim_trailing(linechange.old, "\n")}'\n" <>
      "        |\n" <>
      "        V\n" <>
      "        " <>
      "'#{String.trim_trailing(linechange.new, "\n")}'"
  end

  @spec format_output({Fr.Findtag.t(), pos_integer()}) :: binary()
  defp format_output({%Fr.Findtag{} = findtag, optno}) do
    to_replace =
      if findtag.replace == :user_input do
        "<input>"
      else
        findtag.replace
      end

    "  #{optno}) #{findtag.description}: Find - #{findtag.find}, Replace - #{to_replace}"
  end

  @spec offset_lines([binary()], non_neg_integer()) :: [binary()]
  defp offset_lines(lines, offset) when is_list(lines) and is_integer(offset) do
    cond do
      Enum.count(lines) < @prompt_height ->
        lines

      Enum.count(lines) - offset < @prompt_height ->
        Enum.slice(lines, Enum.count(lines) - @prompt_height, @prompt_height)

      true ->
        Enum.slice(lines, offset, @prompt_height)
    end
  end

  @spec windowed_output([{binary(), [{Fr.Linechange.t(), pos_integer()}]}], non_neg_integer()) :: [binary()]
  defp windowed_output([{_fp, [{%Fr.Linechange{}, _optno} | _]} | _] = artifacts, offset)
       when is_integer(offset) do
    artifact_lines =
      Enum.map(artifacts, fn {filepath, linechanges} ->
        filepath <>
          "\n" <>
          (Enum.map(linechanges, fn artifact -> format_output(artifact) end)
           |> Enum.join("\n"))
      end)
      |> Enum.join("\n")
      |> String.split("\n")

    offset_lines(artifact_lines, offset)
  end

  @spec windowed_output([{binary(), [{Fr.Findtag.t(), pos_integer()}]}], non_neg_integer()) :: [binary()]
  defp windowed_output([{%Fr.Findtag{}, _optno} | _] = artifacts, offset) when is_integer(offset) do
    Enum.map(artifacts, fn artifact -> format_output(artifact) end)
    |> offset_lines(offset)
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

  @spec findtag_prompt([{Fr.Findtag.t(), pos_integer()}], integer()) ::
          {:ok, Fr.Findtag.t()} | {:cancelled, binary()}
  def findtag_prompt(artifacts, offset) do
    print_artifacts(artifacts, offset)

    user_input =
      prompt("Enter the number of the findtag you want to use. 'q' to quit, 'h' for help...")

    case Integer.parse(user_input) do
      :error ->
        case String.downcase(user_input) do
          "q" ->
            cancel()

          "h" ->
            print_help(:findtag)
            findtag_prompt(artifacts, offset)

          _ ->
            input_error(user_input)
            findtag_prompt(artifacts, offset)
        end

      {optno, _} ->
        if optno > length(artifacts) or optno < 1 do
          input_error(user_input)
          findtag_prompt(artifacts, offset)
        else
          parsed_findtag =
            Fr.Proc.Findtags.select(optno)
            |> parse_replace()
            |> Fr.Proc.Findtags.update_selected(:replace)

          {:ok, parsed_findtag}
        end
    end
  end

  def confirm_prompt(offset) when is_integer(offset) do
    IO.puts("The following lines will be modified...")

    Fr.Proc.Linechanges.filechanges()
    |> print_artifacts(offset)

    to_continue = prompt("Continue? y/N")

    if String.downcase(String.trim(to_continue)) == "y" do
      Fr.Proc.Linechanges.execute()
      :ok
    else
      :cancelled
    end
  end

  def confirm_prompt(%Fr.Findtag{} = findtag, offset) when is_integer(offset) do
    IO.puts("The following lines will be modified...")

    Fr.Proc.Linechanges.filechanges()
    |> print_artifacts(offset)

    to_continue = prompt("Continue? y/N")

    if String.downcase(String.trim(to_continue)) == "y" do
      Fr.Proc.Linechanges.execute(findtag)
      :ok
    else
      :cancelled
    end
  end

  def linechange_prompt(offset) when is_integer(offset) do
    Fr.Proc.Linechanges.filechanges()
    |> print_artifacts(offset)

    user_input =
      prompt(
        "'-<OPTNO>[-<OPTNO>] to remove line(s) from replace set, 'e' to execute find/replace, 'q' to quit, 'r' to reset replace set, 'h' for help."
      )

    split_input = String.split(user_input, "-")

    case length(split_input) do
      1 ->
        case String.downcase(user_input) do
          "j" ->
            linechange_prompt(offset + 1)

          "k" ->
            linechange_prompt(offset - 1)

          "e" ->
            confirm_prompt(0)

          "q" ->
            cancel()

          "r" ->
            Fr.Proc.Linechanges.reset()
            linechange_prompt(offset)

          "h" ->
            print_help(:linechange)
            linechange_prompt(offset)
        end

      2 ->
        case Integer.parse(Enum.at(split_input, 1)) do
          {num, _} ->
            Fr.Proc.Linechanges.remove(num)
            linechange_prompt(offset)

          :error ->
            input_error(user_input)
            linechange_prompt(offset)
        end

      3 ->
        [_, open, close] = split_input
        {open, _} = Integer.parse(open)
        {close, _} = Integer.parse(close)
        Fr.Proc.Linechanges.remove(open..close)
        linechange_prompt(offset)

      _ ->
        input_error(user_input)
        linechange_prompt(offset)
    end
  end

  @spec linechange_prompt(Fr.Findtag.t()) :: :ok | :cancelled
  def linechange_prompt(%Fr.Findtag{} = findtag, offset) when is_integer(offset) do
    Fr.Proc.Linechanges.filechanges()
    |> print_artifacts(offset)

    user_input =
      prompt(
        "'-<OPTNO>[-<OPTNO>] to remove line(s) from replace set, 'e' to execute find/replace, 'q' to quit, 'r' to reset replace set, 'h' for help."
      )

    split_input = String.split(user_input, "-")

    case length(split_input) do
      1 ->
        case String.downcase(user_input) do
          "j" ->
            linechange_prompt(findtag, offset + 1)

          "k" ->
            linechange_prompt(findtag, offset - 1)

          "e" ->
            confirm_prompt(findtag, offset)

          "q" ->
            cancel()

          "r" ->
            Fr.Proc.Linechanges.reset()
            linechange_prompt(findtag, offset)

          "h" ->
            print_help(:linechange)
            linechange_prompt(findtag, offset)
        end

      2 ->
        case Integer.parse(Enum.at(split_input, 1)) do
          {num, _} ->
            Fr.Proc.Linechanges.remove(num)
            linechange_prompt(findtag, offset)

          :error ->
            input_error(user_input)
            linechange_prompt(findtag, offset)
        end

      3 ->
        [_, open, close] = split_input
        {open, _} = Integer.parse(open)
        {close, _} = Integer.parse(close)
        Fr.Proc.Linechanges.remove(open..close)
        linechange_prompt(findtag, offset)

      _ ->
        input_error(user_input)
        linechange_prompt(findtag, offset)
    end
  end
end
