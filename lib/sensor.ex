defmodule Sensor do
  use GenServer
  defstruct outbound_connections: [],
    sync_function: {0, nil}

  def add_outbound_connection(outbound_connections, to_node_pid, connection_id) do
    outbound_connections ++ [{to_node_pid, connection_id}]
  end

  def send_synapse_to_outbound_connection(sensor_data, to_node_pid, connection_id) do
    synapse = %Synapse{
      connection_id: connection_id,
      from_node_id: self(),
      value: sensor_data
    }

    :ok = GenServer.cast(to_node_pid, {:receive_synapse, synapse})
  end

  def process_sensor_data([],[]) do
    nil
  end

  def process_sensor_data([], [{to_node_pid, connection_id} | remaining_outbound_connections]) do
    send_synapse_to_outbound_connection(0.0, to_node_pid, connection_id)
    process_sensor_data([], remaining_outbound_connections)
  end

  def process_sensor_data([sensor_data | tail_sensor_data], [{to_node_pid, connection_id} | remaining_outbound_connections]) do
    send_synapse_to_outbound_connection(sensor_data, to_node_pid, connection_id)
    process_sensor_data(tail_sensor_data, remaining_outbound_connections)
  end

  def synchronize(sync_function, outbound_connections) do
    sensor_data = sync_function.()
    process_sensor_data(sensor_data, outbound_connections)
  end

  def handle_call({:add_outbound_connection, {to_node_pid, connection_id}}, _from, state) do
    updated_outbound_connections = add_outbound_connection(state.outbound_connections, to_node_pid, connection_id)
    updated_state = %Sensor{state | outbound_connections: updated_outbound_connections}
    {:reply, :ok, updated_state}
  end

  def handle_call(:synchronize, _from, state) do
    {_sync_function_id, sync_function} = state.sync_function
    synchronize(sync_function, state.outbound_connections)
    {:reply, :ok, state}
  end

end
