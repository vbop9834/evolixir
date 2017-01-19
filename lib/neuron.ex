defmodule InboundNeuronConnection do
  defstruct weight: 1.0, connection_id: nil
end

defmodule Synapse do
  defstruct connection_id: nil, from_node_id: nil, value: 0.0
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
    updated_inbound_connections =
      Map.put(inbound_connections, from_node_pid, updated_connections_from_node_pid)
    {updated_inbound_connections, new_connection_id}
  end

  def add_outbound_connection(outbound_connections, to_node_pid, connection_id) do
    outbound_connections ++ [{to_node_pid, connection_id}]
  end

  def send_synapse_to_outbound_connection(synapse, outbound_pid) do
    :ok = GenServer.cast(outbound_pid, {:receive_synapse, synapse})
  end

  def send_output_value_to_outbound_connections(from_node_pid, output_value, outbound_connections) do
    create_synapse =
    (fn to_node_pid, connection_id ->
      %Synapse{
        connection_id: connection_id,
        from_node_id: from_node_pid,
        value: output_value
      }
    end)
    process_connection =
      (fn {to_node_pid, connection_id} ->
        synapse_to_send = create_synapse.(to_node_pid, connection_id)
        send_synapse_to_outbound_connection(synapse_to_send, to_node_pid)
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

  def calculate_output_value(full_barrier) do
    #TODO add activation function
    get_synapse_value =
    (fn {_, synapse} ->
      synapse.value
    end)

    Enum.map(full_barrier, get_synapse_value)
    |> Enum.sum
  end

  def handle_call({:add_outbound_connection, {to_node_pid, connection_id}}, _from, state) do
    updated_outbound_connections = add_outbound_connection(state.outbound_connections, to_node_pid, connection_id)
    updated_state = %Neuron{state | outbound_connections: updated_outbound_connections}
    {:reply, :ok, updated_state}
  end

  def handle_call({:add_inbound_connection, {from_node_pid, weight}}, _from, state) do
    {updated_inbound_connections, new_inbound_connection_id} =
      add_inbound_connection(state.inbound_connections, from_node_pid, weight)
    updated_state = %Neuron{state | inbound_connections: updated_inbound_connections}
    {:reply, {:ok, new_inbound_connection_id} , updated_state}
  end

  def handle_cast({:receive_synapse, synapse}, state) do
    #TODO pattern match error here if nil
    inbound_connection_weight =
      Map.get(state.inbound_connections, synapse.connection_id)
    weighted_synapse =
      apply_weight_to_synapse(synapse, inbound_connection_weight)
    updated_barrier =
      Map.put(state.barrier, {weighted_synapse.from_node_id, weighted_synapse.connection_id}, weighted_synapse)
    updated_state =
      if Map.has_key?(state.barrier, {weighted_synapse.from_node_id, weighted_synapse.connection_id}) do
        #check if barrier is full
        if is_barrier_full?(updated_barrier, state.inbound_connections) do
          output_value = calculate_output_value(updated_barrier)
          send_output_value_to_outbound_connections(self(), output_value, state.oubound_connections)
          %Neuron{state |
           barrier: Map.new()
          }
        else
          %Neuron{state |
           barrier: updated_barrier
          }
        end
      else
        %Neuron{state |
                barrier: updated_barrier
        }
      end
    {:noreply, updated_state}
  end
end
