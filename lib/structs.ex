defmodule Fr.Findtag do
  @moduledoc """
  Struct describing a specific fr-structured comment.
  """

  @enforce_keys [:description, :find, :replace, :fp, :lineno, :fullline]
  defstruct [:description, :find, :replace, :fp, :lineno, :fullline]

  @type t :: %__MODULE__{
          description: String.t(),
          find: binary(),
          replace: binary() | :user_input,
          fp: binary(),
          lineno: pos_integer(),
          fullline: binary()
        }
end

defmodule Fr.Linechange do
  @enforce_keys [:old, :new, :fp, :lineno]
  defstruct [:old, :new, :fp, :lineno]
  @type t :: %__MODULE__{old: binary(), new: binary(), fp: binary(), lineno: pos_integer()}
end
