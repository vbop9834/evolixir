defmodule Sensor do
  use GenServer
  defstruct outbound_connections: [],
    sync_function: {0, nil},
    sensor_id: 0,
    registry_func: nil

  def start_link(sensor) do
    case sensor.registry_func do
    nil ->
        GenServer.start_link(Sensor, sensor)
    reg_func ->
        sensor_name = reg_func.(sensor.sensor_id)
        GenServer.start_link(Sensor, sensor, name: sensor_name)
    end
  end

  def send_synapse_to_outbound_connection(registry_func, sensor_id, sensor_data, to_node_pid, connection_id) do
    synapse = %Synapse{
      connection_id: connection_id,
      from_node_id: sensor_id,
      value: sensor_data
    }

    case registry_func do
      nil ->
        :ok = GenServer.cast(to_node_pid, {:receive_synapse, synapse})
      reg_func ->
        outbound_pid_with_via = reg_func.(to_node_pid)
        :ok = GenServer.cast(outbound_pid_with_via, {:receive_synapse, synapse})
    end
  end

  def process_sensor_data(_registry_func, _sensor_id, [],[]) do
    :ok
  end

  def process_sensor_data(_registry_func, _sensor_id, _data, []) do
    :ok
  end

  def process_sensor_data(registry_func, sensor_id, [], [{to_node_pid, connection_id} | remaining_outbound_connections]) do
    send_synapse_to_outbound_connection(registry_func, sensor_id, 0.0, to_node_pid, connection_id)
    process_sensor_data(registry_func, sensor_id, [], remaining_outbound_connections)
  end

  def process_sensor_data(registry_func, sensor_id, [sensor_data | tail_sensor_data], [{to_node_pid, connection_id} | remaining_outbound_connections]) do
    send_synapse_to_outbound_connection(registry_func, sensor_id, sensor_data, to_node_pid, connection_id)
    process_sensor_data(registry_func, sensor_id, tail_sensor_data, remaining_outbound_connections)
  end

  def synchronize(registry_func, sensor_id, sync_function, outbound_connections) do
    sensor_data = sync_function.()
    process_sensor_data(registry_func, sensor_id, sensor_data, outbound_connections)
  end

  def handle_call(:synchronize, _from, state) do
    {_sync_function_id, sync_function} = state.sync_function
    synchronize(state.registry_func, state.sensor_id, sync_function, state.outbound_connections)
    {:reply, :ok, state}
  end

  def add_outbound_connection(outbound_connections, to_node_id, connection_id) do
    outbound_connections ++ [{to_node_id, connection_id}]
  end

  def add_outbound_connection(to_node_pid, connection_id) do
    add_outbound_connection([], to_node_pid, connection_id)
  end

  #The reason for keeping sensor outbound connections a list
  #Is to ensure outbound vector data order
  #Changing this to a map means that order has to be enforced
  #through code rather data structure
  #problem is this operation is O(n)
  #So if this is to be solved for
  #Then the Live sensor synchronization order should be solved as well
  def remove_outbound_connection(outbound_connections, to_node_id, connection_id) do
    List.delete(outbound_connections, {to_node_id, connection_id})
  end

  def connect_to_neuron(sensor, neuron, weight) do
    {updated_inbound_connections, new_connection_id} =
      NeuralNode.add_inbound_connection(neuron.inbound_connections, sensor.sensor_id, weight)
    updated_outbound_connections =
      Sensor.add_outbound_connection(sensor.outbound_connections, neuron.neuron_id, new_connection_id)
    updated_sensor = %Sensor{sensor |
                             outbound_connections: updated_outbound_connections
                            }
    updated_neuron = %Neuron{neuron |
                             inbound_connections: updated_inbound_connections
                            }
    {updated_sensor, updated_neuron}
  end

end
