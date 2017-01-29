defmodule CortexController do
  use GenServer
  defstruct registry_func: nil,
    sensors: [],
    neurons: Map.new(),
    actuators: []

  def start_link(name, cortex_controller) do
    GenServer.start_link(CortexController, cortex_controller, name: name)
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

  def set_recursive_neural_network_state(registry_func, neurons) do
    send_recursive_synapse_to_inbound_connection =
      fn to_node_id, from_node_id, {connection_id, _weight} ->
        synapse = %Synapse{
          connection_id: connection_id,
          from_node_id: from_node_id,
          value: 0.0
        }
        node_name = registry_func.(to_node_id)
        GenServer.call(node_name, {:receive_blank_synapse, synapse})
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
      sensor_name = sensor.registry_func.(sensor.sensor_id)
      GenServer.call(sensor_name, :synchronize)
    end
    Enum.each(sensors, synchronize_sensor)
  end

  def wait_on_actuators(_registry_func, []) do
    :ok
  end

  def wait_on_actuators(registry_func, [actuator | actuators_remaining]) do
    actuator_name = registry_func.(actuator.actuator_id)
    actuator_has_been_activated = GenServer.call(actuator_name, :has_been_activated)
    case actuator_has_been_activated do
      true ->
        wait_on_actuators(registry_func, actuators_remaining)
      false ->
        actuators = [actuator] ++ actuators_remaining
        wait_on_actuators(registry_func, actuators)
    end
  end

  def handle_call(:think, _from, state) do
    synchronize_sensors(state.sensors)
    wait_on_actuators(state.registry_func, state.actuators)
    {:reply, :ok, state}
  end

  def handle_call(:reset_network, _from, state) do
    set_recursive_neural_network_state(state.registry_func, state.neurons)
    {:reply, :ok, state}
  end
end

defmodule Cortex do
  use Supervisor
  defstruct cortex_controller_pid: nil,
    registry_name: nil,
    registry_func: nil,
    sensors: [],
    neurons: Map.new(),
    actuators: []

  defp get_neurons_with_registry(registry_func, {layer, neuron_structs}) do
    get_neuron_struct =
      fn neuron_struct ->
        %Neuron{neuron_struct |
                registry_func: registry_func
        }
    end

    {layer, Enum.map(neuron_structs, get_neuron_struct)}
  end

  defp get_child_neurons_for_layer({_layer, neuron_structs}) do
    get_child_neuron =
      fn neuron_struct ->
        neuron_name = neuron_struct.registry_func.(neuron_struct.neuron_id)
        worker(Neuron, [neuron_struct], restart: :transient, id: neuron_name)
      end
    Enum.map(neuron_structs, get_child_neuron)
  end

  defp get_sensor_with_registry(registry_func, sensor_struct) do
    %Sensor{sensor_struct |
            registry_func: registry_func
    }
  end

  defp get_sensor_child(sensor_struct) do
    sensor_name = sensor_struct.registry_func.(sensor_struct.sensor_id)
    worker(Sensor, [sensor_struct], restart: :transient, id: sensor_name)
  end

  defp get_actuator_child(registry_func, actuator_struct) do
    actuator_name = registry_func.(actuator_struct.actuator_id)
    worker(Actuator, [registry_func, actuator_struct], restart: :transient, id: actuator_name)
  end

  def think(registry_name, cortex_id) do
    via_tuple = {:via, Registry, {registry_name, {cortex_id, :controller}}}
    :ok = GenServer.call(via_tuple, :think)
  end

  def reset_network(registry_name, cortex_id) do
    via_tuple = {:via, Registry, {registry_name, {cortex_id, :controller}}}
    :ok = GenServer.call(via_tuple, :reset_network)
  end

  def start_link(registry_name, cortex_controller_pid, sensors, neurons, actuators) do
    registry_func = fn outbound_pid ->
                      {:via, Registry,
                       {registry_name, {cortex_controller_pid, outbound_pid}}
                      }
    end
    sensors_with_registry = Enum.map(sensors, &get_sensor_with_registry(registry_func, &1))
    neurons_with_registry = Enum.map(neurons, &get_neurons_with_registry(registry_func, &1))

    cortex = %Cortex{
      registry_func: registry_func,
      registry_name: registry_name,
      cortex_controller_pid: cortex_controller_pid,
      sensors: sensors_with_registry,
      neurons: neurons_with_registry,
      actuators: actuators
    }
    Supervisor.start_link(__MODULE__, cortex)
  end

  def init(cortex) do
    cortex_controller_id = {:via, Registry, {cortex.registry_name, {cortex.cortex_controller_pid, :controller}}}
    controller_child = worker(CortexController,
      [cortex_controller_id, %CortexController{
        registry_func: cortex.registry_func,
        neurons: cortex.neurons,
        sensors: cortex.sensors,
        actuators: cortex.actuators
      }], restart: :transient, id: cortex_controller_id)
    sensor_children = Enum.map(cortex.sensors, &get_sensor_child/1)
    actuator_children = Enum.map(cortex.actuators, &get_actuator_child(cortex.registry_func, &1))
    neuron_children =
      Enum.map(cortex.neurons, &get_child_neurons_for_layer/1)
      |> Enum.concat
    children = [controller_child] ++ sensor_children ++ neuron_children ++ actuator_children

    #TODO need to send recursive blank synapses too on restart
    supervise(children, strategy: :one_for_all)
  end
end
