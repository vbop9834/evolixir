defmodule InboundNeuronConnection do
  defstruct weight: 1.0, connection_id: nil
end

defmodule Synapse do
  defstruct connection_id: nil, from_node_id: nil, to_node_id: nil, value: 0.0
end

defmodule Neuron do
  use GenServer
  defstruct barrier: Map.new(), inbound_connections: Map.new(), outbound_connections: []

  def add_inbound_connection(inbound_connections, from_node_pid, weight) do
    connections_from_node_pid = Map.get(inbound_connections, from_node_pid, [])
    new_connection_id = Enum.count(connections_from_node_pid) + 1
    new_inbound_connection = %InboundNeuronConnection{connection_id: new_connection_id, weight: weight}
    updated_connections_from_node_pid =
      connections_from_node_pid ++ [new_inbound_connection]
    Map.put(inbound_connections, from_node_pid, updated_connections_from_node_pid)
  end

  def add_outbound_connection(outbound_connections, to_node_pid) do
    outbound_connections ++ [to_node_pid]
  end

  def send_synapse_to_outbound_connection(synapse, outbound_pid) do
    :ok = GenServer.cast(outbound_pid, {:receive_synapse, synapse})
  end

  def send_synapse_to_outbound_connections(synapse, outbound_connections) do
    process_connection =
      (fn pid ->
        send_synapse_to_outbound_connection(synapse, pid)
      end)
    Enum.each(outbound_connections, process_connection)
  end

  def is_barrier_full?(barrier, inbound_connections) do
    connection_is_in_barrier? =
      (fn {from_node_id, inbound_connections} ->
        find_connection_in_barrier =
          (fn inbound_connection ->
            Map.has_key?(barrier, inbound_connection.connection_id)
          end)
        Enum.all?(inbound_connections, find_connection_in_barrier)
      end)
    Enum.all?(inbound_connections, connection_is_in_barrier?)
  end

  def apply_weight_to_synapse(synapse, inbound_connection_weight) do
    weighted_value = synapse.value * inbound_connection_weight
    %Synapse{synapse | value: weighted_value}
  end

  def handle_cast({:receive_synapse, synapse}, state) do
    #TODO pattern match error here if nil
    inbound_connection_weight =
      Map.get(state.inbound_connections, synapse.connection_id)
    weighted_synapse =
      apply_weight_to_synapse(synapse, inbound_connection_weight)
    updated_barrier =
      Map.put(state.barrier, weighted_synapse.connection_id, weighted_synapse)
    updated_state =
      if Map.has_key?(state.barrier, weighted_synapse.connection_id) do
        #check if barrier is full
        if is_barrier_full?(state.barrier, state.inbound_connections) do
          send_synapse_to_outbound_connections(weighted_synapse, state.oubound_connections)
          %Neuron{state |
           barrier: Map.new()
          }
        else
          %Neuron{state |
           barrier: updated_barrier
          }
        end
      else
      end
    {:noreply, updated_state}
  end
end
