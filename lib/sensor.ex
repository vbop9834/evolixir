defmodule Sensor do
  use GenServer
  defstruct outbound_connections: [],
    sync_function: {0, nil},
    sensor_id: 0

  def send_synapse_to_outbound_connection(sensor_id, sensor_data, to_node_pid, connection_id) do
    synapse = %Synapse{
      connection_id: connection_id,
      from_node_id: sensor_id,
      value: sensor_data
    }

    :ok = GenServer.cast(to_node_pid, {:receive_synapse, synapse})
  end

  def process_sensor_data(_sensor_id, [],[]) do
    nil
  end

  def process_sensor_data(sensor_id, [], [{to_node_pid, connection_id} | remaining_outbound_connections]) do
    send_synapse_to_outbound_connection(sensor_id, 0.0, to_node_pid, connection_id)
    process_sensor_data(sensor_id, [], remaining_outbound_connections)
  end

  def process_sensor_data(sensor_id, [sensor_data | tail_sensor_data], [{to_node_pid, connection_id} | remaining_outbound_connections]) do
    send_synapse_to_outbound_connection(sensor_id, sensor_data, to_node_pid, connection_id)
    process_sensor_data(sensor_id, tail_sensor_data, remaining_outbound_connections)
  end

  def synchronize(sensor_id, sync_function, outbound_connections) do
    sensor_data = sync_function.()
    process_sensor_data(sensor_id, sensor_data, outbound_connections)
  end

  def handle_call(:synchronize, _from, state) do
    {_sync_function_id, sync_function} = state.sync_function
    synchronize(state.sensor_id, sync_function, state.outbound_connections)
    {:reply, :ok, state}
  end

end
