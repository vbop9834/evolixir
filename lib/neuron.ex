defmodule Synapse do
  defstruct connection_id: nil,
    from_node_id: nil,
    value: 0.0
end

defmodule ActivationFunction do
  def id(x) do
    x
  end

  def sigmoid(x) do
    1.0 / (1.0 + :math.exp(-x))
  end
end

defmodule Neuron do
  use GenServer
  defstruct barrier: Map.new(),
    inbound_connections: Map.new(),
    outbound_connections: [],
    activation_function: {:sigmoid, &ActivationFunction.sigmoid/1},
    neuron_id: nil

  def apply_weight_to_synapse(synapse, inbound_connection_weight) do
    weighted_value = synapse.value * inbound_connection_weight
    %Synapse{synapse | value: weighted_value}
  end

  def send_synapse_to_outbound_connection(synapse, outbound_pid) do
    :ok = GenServer.cast(outbound_pid, {:receive_synapse, synapse})
  end

  def send_output_value_to_outbound_connections(from_node_pid, output_value, outbound_connections) do
    process_connection =
    (fn {to_node_pid, connection_id} ->
      synapse_to_send =
        %Synapse{
          connection_id: connection_id,
          from_node_id: from_node_pid,
          value: output_value
        }
      send_synapse_to_outbound_connection(synapse_to_send, to_node_pid)
    end)
    Enum.each(outbound_connections, process_connection)
  end

  def calculate_output_value(full_barrier, activation_function) do
    #TODO add activation function
    get_synapse_value =
    (fn {_, synapse} ->
      synapse.value
    end)

    Enum.map(full_barrier, get_synapse_value)
    |> Enum.sum
    |> activation_function.()
  end

  def handle_cast({:receive_synapse, synapse}, state) do
    #TODO pattern match error here if nil
    connections_from_node =
      Map.get(state.inbound_connections, synapse.from_node_id)
    inbound_connection_weight =
      Map.get(connections_from_node, synapse.connection_id)
    weighted_synapse =
      apply_weight_to_synapse(synapse, inbound_connection_weight)
    updated_barrier =
      Map.put(state.barrier, {weighted_synapse.from_node_id, weighted_synapse.connection_id}, weighted_synapse)
    updated_state =
      #check if barrier is full
      if Node.is_barrier_full?(updated_barrier, state.inbound_connections) do
        {_activation_function_id, activation_function} = state.activation_function
        output_value = calculate_output_value(updated_barrier, activation_function)
        send_output_value_to_outbound_connections(state.neuron_id, output_value, state.outbound_connections)
        %Neuron{state |
                barrier: Map.new()
        }
      else
        %Neuron{state |
                barrier: updated_barrier
        }
      end
    {:noreply, updated_state}
  end

  def handle_cast({:receive_blank_synapse, synapse}, state) do
    #TODO pattern match error here if nil
    updated_barrier =
      Map.put(state.barrier, {synapse.from_node_id, synapse.connection_id}, synapse)
    updated_state =
      %Neuron{state |
              barrier: updated_barrier
             }
    {:noreply, updated_state}
  end

end
