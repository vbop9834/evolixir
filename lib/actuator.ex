defmodule Actuator do
  use GenServer
  defstruct inbound_connections: Map.new(),
    barrier: Map.new(),
    activate_function: nil

  def calculate_output_value(barrier) do
    get_synapse_value =
    (fn {_, synapse} ->
      synapse.value
    end)

    Enum.map(barrier, get_synapse_value)
    |> Enum.sum
  end

  def handle_call({:add_inbound_connection, from_node_pid}, _from, state) do
    {updated_inbound_connections, new_inbound_connection_id} =
      Node.add_inbound_connection(state.inbound_connections, from_node_pid, nil)
    updated_state = %Actuator{state | inbound_connections: updated_inbound_connections}
    {:reply, {:ok, new_inbound_connection_id} , updated_state}
  end

  def handle_cast({:receive_synapse, synapse}, state) do
    updated_barrier =
      Map.put(state.barrier, {synapse.from_node_id, synapse.connection_id}, synapse)
    updated_state =
    #check if barrier is full
    if Node.is_barrier_full?(updated_barrier, state.inbound_connections) do
      calculate_output_value(updated_barrier)
      |> state.activate_function.()
      %Actuator{state |
              barrier: Map.new()
      }
    else
      %Actuator{state |
              barrier: updated_barrier
      }
    end
    {:noreply, updated_state}
  end

end
