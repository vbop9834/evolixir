defmodule Actuator do
  use GenServer
  defstruct inbound_connections: Map.new(),
    barrier: Map.new(),
    actuator_function: {0, nil},
    has_been_activated: false,
    actuator_id: 0

  @type actuator :: Actuator
  @type actuator_id :: NeuralNode.node_id
  @type actuators :: [{actuator_id, actuator}]
  @type actuator_function() :: output_value

  @typep output_value :: NeuralNode.output_value
  @typep connection_id :: NeuralNode.connection_id
  @typep registry_func :: Cortex.registry_func
  @typep barrier :: NeuralNode.barrier
  @typep synapse :: Synapse

  @spec create(actuators, actuator_id, actuator_function) :: {:ok, actuators}
  def create(actuators, actuator_id, actuator_function) do
    actuator = %Actuator{
      actuator_id: actuator_id,
      actuator_function: actuator_function
    }
    actuators = Map.put(actuators, actuator_id, actuator)
    {:ok, actuators}
  end

  @spec update(actuators, actuator_id, actuator) :: {:ok, actuators}
  def update(actuators, actuator_id, actuator) do
    actuators = Map.put(actuators, actuator_id, actuator)
    {:ok, actuators}
  end

  @spec get_actuator(actuators, actuator_id) :: {:ok, actuator} | {:error, String.t()}
  def get_actuator(actuators, actuator_id) do
    case Map.get(actuators, actuator_id) do
      nil -> {:error, "Actuator id is not in the actuators map"}
      actuator -> {:ok, actuator}
    end
  end

  @spec get_random_actuator(actuators) :: {:ok, actuator_id}
  def get_random_actuator(actuators) do
    {actuator_id, _actuator} = Enum.random(actuators)
    {:ok, actuator_id}
  end

  @spec remove_inbound_connection(actuators, Neuron.neuron_id, actuator_id, connection_id) :: {:ok, actuators}
  defp remove_inbound_connection(actuators, from_neuron_id, actuator_id, connection_id) do
    actuator = Map.get(actuators, actuator_id)
    {:ok, inbound_connections} = NeuralNode.remove_inbound_connection(actuator.inbound_connections, from_neuron_id, connection_id)
    actuator = %Actuator{actuator | inbound_connections: inbound_connections}
    {:ok, actuators} = update(actuators, actuator_id, actuator)
    {:ok, actuators}
  end

  @spec add_inbound_connection(actuators, Neuron.neuron_id, actuator_id) :: {:ok, {connection_id}}
  defp add_inbound_connection(actuators, from_neuron_id, actuator_id) do
    actuator = Map.get(actuators, actuator_id)
    {:ok, {inbound_connections, connection_id}} = NeuralNode.add_inbound_connection(actuator.inbound_connections, from_neuron_id, 0.0)
    actuator = %Actuator{actuator | inbound_connections: inbound_connections}
    {:ok, actuators} = update(actuators, actuator_id, actuator)
    {:ok, {connection_id, actuators}}
  end

  @spec connect_neuron_to_actuator(Neuron.neurons, actuators, Neuron.neuron_layer, Neuron.neuron_id, actuator_id) :: {:ok, {Neuron.neurons, actuators}}
  def connect_neuron_to_actuator(neurons, actuators, from_neuron_layer, from_neuron_id, actuator_id) do
    {:ok, {connection_id, actuators}} = add_inbound_connection(actuators, from_neuron_id, actuator_id)
    {:ok, neurons} = Neuron.add_outbound_connection(neurons, from_neuron_layer, from_neuron_id, actuator_id, connection_id)
    {:ok, {neurons, actuators}}
  end

  @spec disconnect_neuron_from_actuator(Neuron.neurons, actuator, Neuron.neuron_layer, Neuron.neuron_id, actuator_id, connection_id) :: {:ok, {Neuron.neurons, actuators}}
  def disconnect_neuron_from_actuator(neurons, actuators, from_neuron_layer, from_neuron_id, actuator_id, connection_id) do
    {:ok, neurons} = Neuron.remove_outbound_connection(neurons, from_neuron_layer, from_neuron_id, actuator_id, connection_id)
    {:ok, actuators} = remove_inbound_connection(actuators, from_neuron_id, actuator_id, connection_id)
    {:ok, {neurons, actuators}}
  end

  @spec start_link(registry_func, actuator) :: {:ok, pid}
  def start_link(registry_func, actuator) do
    actuator_name = registry_func.(actuator.actuator_id)
    GenServer.start_link(Actuator, actuator, name: actuator_name)
  end

  @spec start_link(actuator) :: {:ok, pid}
  def start_link(actuator) do
    GenServer.start_link(Actuator, actuator)
  end

  @spec calculate_output_value(barrier) :: output_value
  def calculate_output_value(barrier) do
    get_synapse_value =
    (fn {_, synapse} ->
      synapse.value
    end)

    Enum.map(barrier, get_synapse_value)
    |> Enum.sum
  end

  @spec handle_cast({:receive_synapse, synapse}, actuator) :: {:noreply, actuator}
  def handle_cast({:receive_synapse, synapse}, state) do
    updated_barrier =
      Map.put(state.barrier, {synapse.from_node_id, synapse.connection_id}, synapse)
    updated_state =
    #check if barrier is full
    if NeuralNode.is_barrier_full?(updated_barrier, state.inbound_connections) do
      {_actuator_function_id, actuator_function} = state.actuator_function
      calculate_output_value(updated_barrier)
      |> actuator_function.()
      %Actuator{state |
              has_been_activated: true,
              barrier: Map.new()
      }
    else
      %Actuator{state |
              barrier: updated_barrier
      }
    end
    {:noreply, updated_state}
  end

  @spec handle_cast({:receive_blank_synapse, synapse}, actuator) :: {:noreply, actuator}
  def handle_cast({:receive_blank_synapse, synapse}, state) do
    updated_barrier =
      Map.put(state.barrier, {synapse.from_node_id, synapse.connection_id}, synapse)
    updated_state =
      %Actuator{state |
                barrier: updated_barrier
               }
    {:noreply, updated_state}
  end

  @spec handle_call(:has_been_activated, pid, actuator) :: {:reply, boolean, actuator}
  def handle_call(:has_been_activated, _from, state) do
    updated_state =
      case state.has_been_activated do
        true ->
          %Actuator{state |
                    has_been_activated: false
                   }
        false -> state
      end
    {:reply, state.has_been_activated, updated_state}
  end

end
