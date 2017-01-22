defmodule NodeTestHelper do
  use GenServer
  defstruct received_synapses: {},
    was_activated: false

  def handle_cast({:receive_synapse, synapse}, state) do
    updated_received_synapses = Tuple.append(state.received_synapses, synapse)
    updated_state = %NodeTestHelper{state | received_synapses: updated_received_synapses}
    {:noreply, updated_state}
  end

  def handle_call({:activate, value}, _from, state) do
    updated_state = %NodeTestHelper{state |
                                    was_activated: {true, value}
                                   }
    {:reply, :ok, updated_state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end

ExUnit.start()
