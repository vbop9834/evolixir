defmodule Cortex do
  use Supervisor
  defstruct sensors: [],
    neurons: Map.new(),
    actuators: []

  def get_child_neurons_for_layer({_layer, neuron_structs}) do
    get_child_neuron =
      fn neuron_struct ->
        worker(Neuron, [neuron_struct], restart: :transient, id: neuron_struct.neuron_id)
      end
    Enum.map(neuron_structs, get_child_neuron)
  end

  def get_sensor_child(sensor_struct) do
    worker(Sensor, [sensor_struct], restart: :transient, id: sensor_struct.sensor_id)
  end

  def get_actuator_child(actuator_struct) do
    worker(Actuator, [actuator_struct], restart: :transient, id: actuator_struct.actuator_id)
  end

  def is_connection_recursive?(neurons, from_neuron_layer, to_neuron_id) do
    find_neuron_layer =
      fn {layer, neuron_structs} ->
        case Enum.any?(neuron_structs, fn neuron_struct -> neuron_struct.neuron_id == to_neuron_id end) do
          true -> layer
          false -> nil
        end
      end
    to_neuron_layer =
      Enum.find_value(neurons, nil, find_neuron_layer)
    from_neuron_layer >= to_neuron_layer
  end

  def set_recursive_neural_network_state(neurons) do
    send_recursive_synapse_to_inbound_connection =
      fn to_node_id, from_node_id, {connection_id, _weight} ->
        synapse = %Synapse{
          connection_id: connection_id,
          from_node_id: from_node_id,
          value: 0.0
        }
        GenServer.call(to_node_id, {:receive_blank_synapse, synapse})
      end
    check_connections_from_node =
      fn from_neuron_layer, to_node_id, {from_node_id, connections_from_node} ->
        case is_connection_recursive?(neurons, from_neuron_layer, to_node_id) do
          true ->
            Enum.each(connections_from_node,
              &send_recursive_synapse_to_inbound_connection.(to_node_id, from_node_id, &1)
            )
          false -> ()
        end
      end
    check_inbound_connections =
      fn from_neuron_layer, neuron_struct ->
        to_node_id = neuron_struct.neuron_id
        inbound_connections = neuron_struct.inbound_connections
        Enum.each(inbound_connections, &check_connections_from_node.(from_neuron_layer, to_node_id, &1))
      end
    check_and_send_recursive_synapses_for_layer =
      fn {from_neuron_layer, neuron_structs} ->
        Enum.each(neuron_structs, &check_inbound_connections.(from_neuron_layer,&1))
      end
    Enum.each(neurons, check_and_send_recursive_synapses_for_layer)
  end

  def synchronize_sensors(sensors) do
    synchronize_sensor =
      fn sensor ->
        GenServer.call(sensor.sensor_id, :synchronize)
      end
    Enum.each(sensors, synchronize_sensor)
  end

  def wait_on_actuators([]) do
    :ok
  end

  def wait_on_actuators([actuator | actuators_remaining]) do
    actuator_has_been_activated = GenServer.call(actuator.actuator_id, :has_been_activated)
    case actuator_has_been_activated do
      true ->
        wait_on_actuators(actuators_remaining)
      false ->
        actuators = [actuator] ++ actuators_remaining
        wait_on_actuators(actuators)
    end
  end

  def start_link(cortex_name, sensors, neurons, actuators) do
    cortex = %Cortex{
      sensors: sensors,
      neurons: neurons,
      actuators: actuators
    }
    Supervisor.start_link(__MODULE__, cortex, name: cortex_name)
  end

  def init(cortex) do
    child_sensors =
      Enum.map(cortex.sensors, &get_sensor_child/1)
    child_actuators =
      Enum.map(cortex.actuators, &get_actuator_child/1)
    child_neurons =
      Enum.map(cortex.neurons, &get_child_neurons_for_layer/1)
      |> Enum.concat
    children = child_sensors ++ child_actuators ++ child_neurons
    supervise(children, strategy: :one_for_all)
  end
end
