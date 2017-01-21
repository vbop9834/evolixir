defmodule NeuronTestHelper do
  use GenServer
  defstruct received_synapses: {}

  def handle_cast({:receive_synapse, synapse}, state) do
    updated_received_synapses = Tuple.append(state.received_synapses, synapse)
    updated_state = %NeuronTestHelper{state | received_synapses: updated_received_synapses}
    {:noreply, updated_state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end

ExUnit.start()
