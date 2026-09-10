defmodule Spear.Connection.Response do
  @moduledoc false

  # a slim data structure for storing information about an HTTP/2 response

  @type t :: %__MODULE__{}

  defstruct [:status, :type, headers: [], data: <<>>]
end
