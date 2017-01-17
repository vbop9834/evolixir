defmodule Neuron do
  defstruct [
    :outputValue,
    :barrier,
    :inbound_connections,
    :outbound_connections,
    :has_fired
  ]
  use GenServer

  def handle_cast({:receive_synapse, synapse}, state) do
    {:noreply, state}
  end
end
