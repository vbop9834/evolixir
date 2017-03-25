defmodule CortexController do
  use GenServer
  defstruct registry_func: nil,
    sensors: Map.new(),
    neurons: Map.new(),
    actuators: Map.new()

  @type cortex_controller :: CortexController

  def start_link(name, cortex_controller) do
    GenServer.start_link(CortexController, cortex_controller, name: name)
  end

  @spec is_connection_recursive?(Neuron.neurons, Neuron.neuron_layer, Neuron.neuron_id) :: boolean
  def is_connection_recursive?(neurons, to_neuron_layer, from_neuron_id) do
      case Neuron.find_neuron_layer(neurons, from_neuron_id) do
      {:error, reason} -> {:error, reason}
      {:ok, from_neuron_layer} ->
        from_neuron_layer >= to_neuron_layer
    end
  end

  @spec set_recursive_neural_network_state(Cortex.registry_func, Neuron.neuron) :: :ok
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
      fn to_neuron_layer, to_node_id, {from_node_id, connections_from_node} ->
        case is_connection_recursive?(neurons, to_neuron_layer, from_node_id) do
          {:error, _reason} -> #ignore because it could be a sensor or actuator
            #TODO check for this before doing these operations
            ()
          true ->
            Enum.each(connections_from_node,
              &send_recursive_synapse_to_inbound_connection.(to_node_id, from_node_id, &1)
            )
          false -> ()
        end
      end
    check_inbound_connections =
      fn to_neuron_layer, {to_node_id, neuron_struct} ->
        inbound_connections = neuron_struct.inbound_connections
        Enum.each(inbound_connections, &check_connections_from_node.(to_neuron_layer, to_node_id, &1))
      end
    check_and_send_recursive_synapses_for_layer =
      fn {to_neuron_layer, neuron_structs} ->
        Enum.each(neuron_structs, &check_inbound_connections.(to_neuron_layer,&1))
      end
    Enum.each(neurons, check_and_send_recursive_synapses_for_layer)
    :ok
  end

  @spec synchronize_sensors(Sensor.sensors) :: :ok
  def synchronize_sensors(sensors) do
    synchronize_sensor =
    fn sensor ->
      sensor_name = sensor.registry_func.(sensor.sensor_id)
      GenServer.call(sensor_name, :synchronize)
    end
    Enum.each(sensors, synchronize_sensor)
    :ok
  end

  @spec wait_on_actuators(Cortex.registry_func, []) :: :ok
  def wait_on_actuators(_registry_func, []) do
    :ok
  end

  @spec wait_on_actuators(Cortex.registry_func, Actuator.actuators) :: :ok
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

  @spec handle_call(:think, pid, cortex_controller) :: {:reply, :ok, cortex_controller}
  def handle_call(:think, _from, state) do
    synchronize_sensors(state.sensors)
    wait_on_actuators(state.registry_func, state.actuators)
    {:reply, :ok, state}
  end

  @spec handle_call(:reset_network, pid, cortex_controller) :: {:reply, :ok, cortex_controller}
  def handle_call(:reset_network, _from, state) do
    :ok = set_recursive_neural_network_state(state.registry_func, state.neurons)
    {:reply, :ok, state}
  end
end

defmodule Cortex do
  use Supervisor
  defstruct perturb_id: nil,
    cortex_id: nil,
    registry_name: nil,
    registry_func: nil,
    sensors: [],
    neurons: Map.new(),
    actuators: []

  @type cortex :: Cortex
  @type cortex_id :: Integer
  @type perturb_id :: Integer
  @type registry_func_sig(id) :: {:via, Registry, {cortex_id, perturb_id, id}}
  @type registry_func :: registry_func_sig(NeuralNode.node_id)

  @typep worker :: :worker | :supervisor

  @spec get_neuron_struct(registry_func, Neuron.neuron) :: Neuron.neuron
  defp get_neuron_struct(registry_func, neuron_struct) do
    %Neuron{neuron_struct |
                        registry_func: registry_func
    }
  end

  @spec update_neurons_with_registry(registry_func, [], Neuron.neurons) :: Neuron.neurons
  defp update_neurons_with_registry(_registry_func, [], neurons) do
    neurons
  end

  @spec update_neurons_with_registry(registry_func, Neuron.neurons, Neuron.neurons) :: Neuron.neurons
  defp update_neurons_with_registry(registry_func, [neuron_to_update | neurons_remaining], neurons_to_return) do
    updated_struct = get_neuron_struct(registry_func, neuron_to_update)
    updated_neurons = Map.put(neurons_to_return, updated_struct.neuron_id, updated_struct)
    update_neurons_with_registry(registry_func, neurons_remaining, updated_neurons)
  end

  @spec get_neurons_with_registry(registry_func, {Neuron.neuron_layer, Neuron.neuron}) :: {Neuron.neuron_layer, Neuron.neuron}
  defp get_neurons_with_registry(registry_func, {layer, neuron_structs}) do
    neuron_structs_no_keys = Map.values(neuron_structs)
    updated_neurons = update_neurons_with_registry(registry_func, neuron_structs_no_keys, Map.new())

    {layer, updated_neurons}
  end

  @spec get_child_neurons_for_layer({Neuron.neuron_layer, Neuron.neuron}) :: worker
  defp get_child_neurons_for_layer({_layer, neuron_structs}) do
    get_child_neuron =
      fn {_neuron_id, neuron_struct} ->
        neuron_name = neuron_struct.registry_func.(neuron_struct.neuron_id)
        worker(Neuron, [neuron_struct], restart: :transient, id: neuron_name)
      end
    Enum.map(neuron_structs, get_child_neuron)
  end

  @spec get_sensor_with_registry(registry_func, {Sensor.sensor_id, Sensor.sensor}) :: Sensor.sensor
  defp get_sensor_with_registry(registry_func, {_sensor_id, sensor_struct}) do
    %Sensor{sensor_struct |
            registry_func: registry_func
    }
  end

  @spec get_sensor_child(Sensor.sensor) :: worker
  defp get_sensor_child(sensor_struct) do
    sensor_name = sensor_struct.registry_func.(sensor_struct.sensor_id)
    worker(Sensor, [sensor_struct], restart: :transient, id: sensor_name)
  end

  @spec get_actuator_child(registry_func, Actuator.actuator) :: worker
  defp get_actuator_child(registry_func, actuator_struct) do
    actuator_name = registry_func.(actuator_struct.actuator_id)
    worker(Actuator, [registry_func, actuator_struct], restart: :transient, id: actuator_name)
  end

  @spec think(atom, {cortex_id, perturb_id}) :: :ok
  def think(registry_name, {cortex_id, perturb_id}) do
    via_tuple = {:via, Registry, {registry_name, {cortex_id, perturb_id, :controller}}}
    :ok = GenServer.call(via_tuple, :think)
    :ok
  end

  @spec think(atom, cortex_id) :: :ok
  def think(registry_name, cortex_id) do
    via_tuple = {:via, Registry, {registry_name, {cortex_id, :controller}}}
    :ok = GenServer.call(via_tuple, :think)
    :ok
  end

  @spec reset_network(atom, {cortex_id, perturb_id}) :: :ok
  def reset_network(registry_name, {cortex_id, perturb_id}) do
    via_tuple = {:via, Registry, {registry_name, {cortex_id, perturb_id, :controller}}}
    :ok = GenServer.call(via_tuple, :reset_network)
    :ok
  end

  @spec reset_network(atom, cortex_id) :: :ok
  def reset_network(registry_name, cortex_id) do
    via_tuple = {:via, Registry, {registry_name, {cortex_id, :controller}}}
    :ok = GenServer.call(via_tuple, :reset_network)
    :ok
  end

  @spec kill_cortex(atom, {cortex_id, perturb_id}) :: :ok
  def kill_cortex(registry_name, {cortex_id, perturb_id}) do
    cortex_name =
    {:via, Registry,
     {registry_name, {cortex_id, perturb_id, :supervisor}}
    }
    Supervisor.stop(cortex_name)
    :ok
  end

  @spec kill_cortex(atom, cortex_id) :: :ok
  def kill_cortex(registry_name, cortex_id) do
    cortex_name =
      {:via, Registry,
       {registry_name, {cortex_id, :supervisor}}
      }
    Supervisor.stop(cortex_name)
    :ok
  end

  @spec get_cortex_properties(atom, cortex_id, perturb_id, registry_func, Sensor.sensors, Neuron.neurons, Actuator.actuators) :: cortex
  defp get_cortex_properties(registry_name, cortex_id, perturb_id, registry_func, sensors, neurons, actuators) do
    sensors_with_registry = Enum.map(sensors, &get_sensor_with_registry(registry_func, &1))
    neurons_with_registry = Enum.map(neurons, &get_neurons_with_registry(registry_func, &1))

    %Cortex{
      cortex_id: cortex_id,
      perturb_id: perturb_id,
      registry_func: registry_func,
      registry_name: registry_name,
      sensors: sensors_with_registry,
      neurons: neurons_with_registry,
      actuators: Map.values(actuators)
    }
  end

  @spec start_link(atom, {cortex_id, perturb_id}, Sensor.sensors, Neuron.neurons, Actuator.actuators) :: {:ok, pid}
  def start_link(registry_name, {cortex_id, perturb_id}, sensors, neurons, actuators) do
    registry_func = fn outbound_pid ->
      {:via, Registry,
       {registry_name, {cortex_id, perturb_id, outbound_pid}}
      }
    end
    cortex_properties = get_cortex_properties(registry_name, cortex_id, perturb_id, registry_func, sensors, neurons, actuators)
    Supervisor.start_link(__MODULE__, cortex_properties, name: registry_func.(:supervisor))
  end

  @spec start_link(atom, cortex_id, Sensor.sensors, Neuron.neurons, Actuator.actuators) :: {:ok, pid}
  def start_link(registry_name, cortex_id, sensors, neurons, actuators) do
    registry_func = fn outbound_pid ->
                      {:via, Registry,
                       {registry_name, {cortex_id, outbound_pid}}
                      }
    end
    perturb_id = nil
    cortex_properties = get_cortex_properties(registry_name, cortex_id, perturb_id, registry_func, sensors, neurons, actuators)
    Supervisor.start_link(__MODULE__, cortex_properties, name: registry_func.(:supervisor))
  end

  @spec init(cortex) :: {:ok, {:supervisor.sup_flags, [Supervisor.Spec.spec]}} 
  def init(cortex) do
    cortex_controller_id =
    case cortex.perturb_id do
      nil ->
        {:via, Registry, {cortex.registry_name, {cortex.cortex_id, :controller}}}
      perturb_id ->
        {:via, Registry, {cortex.registry_name, {cortex.cortex_id, perturb_id, :controller}}}
    end
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
