defmodule Sensor do
  use GenServer
  defstruct outbound_connections: [],
    sync_function: {0, nil},
    maximum_vector_size: 0,
    sensor_id: 0,
    registry_func: nil

  @type sensor :: Sensor
  @type sensor_id :: Integer
  @type sensors :: [{sensor_id, sensor}]
  @type sensor_data :: [Float]
  @typep sensor_data_vector_size :: Integer

  @type sync_function() :: sensor_data
  @type registry_func :: Cortex.registry_func

  @typep connection_id :: Neuron.connection_id
  @typep outbound_connection :: {Neuron.neuron_id, connection_id}
  #The reason for keeping sensor outbound connections a list
  #Is to maintain outbound order
  #Changing this to a map means that order has to be enforced
  #through code rather data structure
  #problem with this approach is that get operations is O(n)
  #So if this is to be solved
  #Then the Live sensor synchronization order should be solved as well
  @typep outbound_connections :: [outbound_connection]

  @spec create(sensors, sensor_id, sync_function) :: {:ok, sensors}
  def create(sensors, sensor_id, sync_function) do
    sensor = %Sensor{
      sensor_id: sensor_id,
      sync_function: sync_function
    }
    sensors = Map.put(sensors, sensor_id, sensor)
    {:ok, sensors}
  end

  @spec get_sensor(sensors, sensor_id) :: {:ok, sensor}
  def get_sensor(sensors, sensor_id) do
    sensor = Map.get(sensors, sensor_id)
    {:ok, sensor}
  end

  @spec get_random_sensor(sensors) :: {:ok, sensor_id}
  def get_random_sensor(sensors) do
    {sensor_id, _sensor} = Enum.random(sensors)
    {:ok, sensor_id}
  end

  @spec start_link(sensor) :: {:ok, pid}
  def start_link(sensor) do
    case sensor.registry_func do
    nil ->
        GenServer.start_link(Sensor, sensor)
    reg_func ->
        sensor_name = reg_func.(sensor.sensor_id)
        GenServer.start_link(Sensor, sensor, name: sensor_name)
    end
  end

  @spec send_synapse_to_outbound_connection(nil, sensor_id, sensor_data, Neuron.neuron_id, connection_id) :: :ok
  def send_synapse_to_outbound_connection(nil, sensor_id, sensor_data, to_neuron_id, connection_id) do
    synapse = %Synapse{
      connection_id: connection_id,
      from_node_id: sensor_id,
      value: sensor_data
    }
    :ok = GenServer.cast(to_neuron_id, {:receive_synapse, synapse})
    :ok
  end

  @spec send_synapse_to_outbound_connection(registry_func, sensor_id, sensor_data, Neuron.neuron_id, connection_id) :: :ok
  def send_synapse_to_outbound_connection(registry_func, sensor_id, sensor_data, to_neuron_id, connection_id) do
    synapse = %Synapse{
      connection_id: connection_id,
      from_node_id: sensor_id,
      value: sensor_data
    }

    neuron_id_with_registry = registry_func.(to_neuron_id)
    :ok = GenServer.cast(neuron_id_with_registry, {:receive_synapse, synapse})
    :ok
  end

  @spec process_sensor_data(registry_func, sensor_id, [], []) :: :ok
  def process_sensor_data(_registry_func, _sensor_id, [],[]) do
    :ok
  end

  @spec process_sensor_data(registry_func, sensor_id, sensor_data, []) :: :ok
  def process_sensor_data(_registry_func, _sensor_id, _data, []) do
    :ok
  end

  @spec process_sensor_data(registry_func, sensor_id, [], outbound_connections) :: :ok
  def process_sensor_data(registry_func, sensor_id, [], [{to_node_pid, connection_id} | remaining_outbound_connections]) do
    send_synapse_to_outbound_connection(registry_func, sensor_id, 0.0, to_node_pid, connection_id)
    process_sensor_data(registry_func, sensor_id, [], remaining_outbound_connections)
  end

  @spec process_sensor_data(registry_func, sensor_id, sensor_data, outbound_connections) :: :ok
  def process_sensor_data(registry_func, sensor_id, [sensor_data | tail_sensor_data], [{to_node_pid, connection_id} | remaining_outbound_connections]) do
    send_synapse_to_outbound_connection(registry_func, sensor_id, sensor_data, to_node_pid, connection_id)
    process_sensor_data(registry_func, sensor_id, tail_sensor_data, remaining_outbound_connections)
  end

  @spec synchronize(registry_func, sensor_id, sync_function, outbound_connections) :: sensor_data_vector_size
  def synchronize(registry_func, sensor_id, sync_function, outbound_connections) do
    sensor_data = sync_function.()
    process_sensor_data(registry_func, sensor_id, sensor_data, outbound_connections)
    Enum.count(sensor_data)
  end

  @spec handle_call(:synchronize, pid, sensor) :: :ok
  def handle_call(:synchronize, _from, state) do
    {_sync_function_id, sync_function} = state.sync_function
    updated_maximum_vector_size =
      synchronize(state.registry_func, state.sensor_id, sync_function, state.outbound_connections)
    maximum_vector_size =
      case updated_maximum_vector_size > state.maximum_vector_size do
        true -> updated_maximum_vector_size
        false -> state.maximum_vector_size
      end
    updated_state = %{state |
                      maximum_vector_size: maximum_vector_size
                     }
    {:reply, :ok, updated_state}
  end

  @spec add_outbound_connection(outbound_connections, Neuron.neuron_id, connection_id) :: outbound_connections
  defp add_outbound_connection(outbound_connections, to_neuron_id, connection_id) do
    outbound_connections ++ [{to_neuron_id, connection_id}]
  end

  @spec add_outbound_connection(sensors, sensor_id, Neuron.neuron_id, connection_id) :: {:ok, sensors}
  defp add_outbound_connection(sensors, sensor_id, neuron_id, connection_id) do
    sensor = Map.get(sensors, sensor_id)
    outbound_connections = add_outbound_connection(sensor.outbound_connections, neuron_id, connection_id)
    sensor = %Sensor{sensor | outbound_connections: outbound_connections}
    sensors = Map.put(sensors, sensor_id, sensor)
    {:ok, sensors}
  end

  @spec remove_outbound_connection(outbound_connections, Neuron.neuron_id, connection_id) :: outbound_connections
  defp remove_outbound_connection(outbound_connections, to_node_id, connection_id) do
    List.delete(outbound_connections, {to_node_id, connection_id})
  end

  @spec remove_outbound_connection(sensors, sensor_id, Neuron.neuron_id, connection_id) :: {:ok, sensors}
  defp remove_outbound_connection(sensors, sensor_id, neuron_id, connection_id) do
    sensor = Map.get(sensors, sensor_id)
    outbound_connections = remove_outbound_connection(sensor.outbound_connections, neuron_id, connection_id)
    sensor = %Sensor{sensor | outbound_connections: outbound_connections}
    sensors = Map.put(sensors, sensor_id, sensor)
    {:ok, sensors}
  end

  @spec disconnect_from_neuron(sensors, Neuron.neurons, sensor_id, Neuron.neuron_layer, Neuron.neuron_id, connection_id) :: {:ok, {sensors, Neuron.neurons}}
  def disconnect_from_neuron(sensors, neurons, sensor_id, neuron_layer, neuron_id, connection_id) do
    {:ok, sensors} = remove_outbound_connection(sensors, sensor_id, neuron_id, connection_id)
    {:ok, neurons} = Neuron.remove_inbound_connection(neurons, sensor_id, neuron_layer, neuron_id, connection_id)
    {:ok, {sensors, neurons}}
  end

  @spec connect_to_neuron(sensors, Neuron.neurons, sensor_id, Neuron.neuron_layer, Neuron.neuron_id, Neuron.weight) :: {:ok, {sensors, Neuron.neurons}}
  def connect_to_neuron(sensors, neurons, sensor_id, neuron_layer, neuron_id, weight) do
    {:ok, {connection_id, neurons}} = Neuron.add_inbound_connection(neurons, sensor_id, neuron_layer, neuron_id, weight)
    {:ok, sensors} = add_outbound_connection(sensors, sensor_id, neuron_id, connection_id)
    {:ok, {sensors, neurons}}
  end

end
