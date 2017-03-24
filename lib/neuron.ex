defmodule Synapse do
  defstruct connection_id: nil,
    from_node_id: nil,
    value: 0.0
end

defmodule ActivationFunction do
  @typep output_value :: Neuron.output_value
  @type activation_function(output_value) :: output_value
  @spec id(output_value) :: output_value
  def id(x) do
    x
  end

  @spec sigmoid(output_value) :: output_value
  def sigmoid(x) do
    1.0 / (1.0 + :math.exp( -x ))
  end
end

defmodule Neuron do
  use GenServer
  defstruct registry_func: nil,
    bias: nil,
    barrier: Map.new(),
    inbound_connections: Map.new(),
    outbound_connections: Map.new(),
    activation_function: {:sigmoid, &ActivationFunction.sigmoid/1},
    neuron_id: nil,
    learning_function: nil

  @type neuron_id :: NeuralNode.node_id
  @type neuron :: Neuron
  @type neuron_layer :: integer
  @type neuron_layer_structs :: [{neuron_id, neuron}]
  @type neurons :: [{neuron_layer, neuron_layer_structs}]

  @typep registry_func :: Cortex.registry_func

  @typep learning_function_name :: atom
  @typep learning_coefficient :: float
  @typep learning_function :: {learning_function_name, learning_coefficient}

  @type bias :: float
  @typep output_value :: NeuralNode.output_value

  @typep barrier :: NeuralNode.barrier
  @typep synapse :: Synapse
  @typep activation_function :: ActivationFunction.activation_function

  @typep connection_id :: NeuralNode.connection_id
  @typep weight :: NeuralNode.weight
  @typep outbound_connection :: {neuron_id, connection_id}
  @typep outbound_connections :: [outbound_connection]
  @typep inbound_connection :: NeuralNode.inbound_connection
  @typep connections_from_node :: NeuralNode.connections_from_node
  @typep inbound_connections :: NeuralNode.inbound_connections

  @spec create(neurons, neuron_layer, neuron_id, activation_function, learning_function) :: {:ok, neurons}
  def create(neurons, neuron_layer, neuron_id, activation_function, learning_function) do
    neuron =
      %Neuron{
        neuron_id: neuron_id,
        activation_function: activation_function,
        learning_function: learning_function
      }
    {:ok, neurons} = add_to_neural_layer(neurons, neuron_layer, [neuron])
    {:ok, neurons}
  end

  @spec add_to_neural_layer(neurons, neuron_layer, []) :: {:ok, neurons}
  def add_to_neural_layer(neurons, _neural_layer, []) do
    {:ok, neurons}
  end

  @spec add_to_neural_layer(neurons, neuron_layer, [neuron]) :: {:ok, neurons}
  def add_to_neural_layer(neurons, neural_layer, [neuron | remaining_neurons]) do
    layer_structs = Map.get(neurons, neural_layer, Map.new())
    layer_structs = Map.put(layer_structs, neuron.neuron_id, neuron)
    neurons = Map.put(neurons, neural_layer, layer_structs)
    add_to_neural_layer(neurons, neural_layer, remaining_neurons)
  end

  @spec add_to_neural_layer(neuron_layer, [neuron]) :: {:ok, neurons}
  def add_to_neural_layer(neural_layer, neurons_to_add) do
    add_to_neural_layer(Map.new(), neural_layer, neurons_to_add)
  end

  @spec update(neurons, neuron_layer, neuron_id, neuron) :: {:ok, neurons}
  def update(neurons, neuron_layer, neuron_id, neuron) do
    neuron_layer_structs = Map.get(neurons, neuron_layer)
    neuron_layer_structs = Map.put(neuron_layer_structs, neuron_id, neuron)
    neurons = Map.put(neurons, neuron_layer, neuron_layer_structs)
    {:ok, neurons}
  end

  @spec change_bias(neurons, neuron_layer, neuron_id, bias) :: {:ok, neurons}
  def change_bias(neurons, neuron_layer, neuron_id, bias) do
    {:ok, neuron} = get_neuron(neurons, neuron_layer, neuron_id)
    neuron = %Neuron{neuron | bias: bias}
    {:ok, neurons} = update(neurons, neuron_layer, neuron_id, neuron)
    {:ok, neurons}
  end

  @spec remove_bias(neurons, neuron_layer, neuron_id) :: {:ok, neurons}
  def remove_bias(neurons, neuron_layer, neuron_id) do
    change_bias(neurons, neuron_layer, neuron_id, nil)
  end

  @spec change_activation_function(neurons, neuron_layer, neuron_id, activation_function) :: {:ok, neurons}
  def change_activation_function(neurons, neuron_layer, neuron_id, activation_function) do
    {:ok, neuron} = get_neuron(neurons, neuron_layer, neuron_id)
    neuron = %Neuron{neuron | activation_function: activation_function}
    {:ok, neurons} = update(neurons, neuron_layer, neuron_id, neuron)
    {:ok, neurons}
  end

  @spec get_neuron(neuron_layer_structs, neuron_id) :: {:ok, neuron} | {:error, String.t()}
  defp get_neuron(neuron_layer_structs, neuron_id) do
    case Map.get(neuron_layer_structs, neuron_id, nil) do
      nil ->
        {:error, "Neuron - Could not find neuron in layer provided"}
      neuron ->
        {:ok, neuron}
    end
  end

  @spec get_neuron(neurons, neuron_layer, neuron_id) :: {:ok, Neuron}
  def get_neuron(neurons, neuron_layer, neuron_id) do
    case Map.get(neurons, neuron_layer, nil) do
      nil -> {:error, "Neuron - Could not find neuron layer"}
      neuron_layer_structs ->
        get_neuron(neuron_layer_structs, neuron_id)
    end
  end

  defp get_highest_neuron_id([], highest_id) do
    highest_id
  end

  defp get_highest_neuron_id([neuron_layer | remaining_layers], highest_id) do
    highest_id_in_layer =
      Map.keys(neuron_layer)
      |> Enum.max
    case highest_id_in_layer > highest_id do
      true -> get_highest_neuron_id(remaining_layers, highest_id_in_layer)
      false -> get_highest_neuron_id(remaining_layers, highest_id)
    end
  end

  @spec get_highest_neuron_id(neurons) :: neuron_id
  def get_highest_neuron_id(neurons) do
    get_highest_neuron_id(Map.values(neurons), 0)
  end

  @spec get_random_neuron(neurons) :: {:ok, {neuron_layer, neuron_id}}
  def get_random_neuron(neurons) do
    {random_layer, random_structs} = Enum.random(neurons)
    {random_neuron_id, _random_neuron} = Enum.random(random_structs)
    {:ok, {random_layer, random_neuron_id}}
  end

  @spec get_random_outbound_connection(neurons, neuron_layer, neuron_id) :: {:ok, outbound_connection}
  def get_random_outbound_connection(neurons, neuron_layer, neuron_id) do
    layer_structs = Map.get(neurons, neuron_layer)
    neuron = Map.get(layer_structs, neuron_id)
    {outbound_connection, _blank} = Enum.random(neuron.outbound_connections)
    {:ok, outbound_connection}
  end

  @spec get_random_inbound_connection(neurons, neuron_layer, neuron_id) :: {:ok, inbound_connection}
  def get_random_inbound_connection(neurons, neuron_layer, neuron_id) do
    {:ok, neuron} = get_neuron(neurons, neuron_layer, neuron_id)
    {from_node_id, connections_from_node} = Enum.random(neuron.inbound_connections)
    {connection_id, weight} = Enum.random(connections_from_node)
    {:ok, {from_node_id, connection_id, weight}}
  end

  @spec get_random_inbound_connections_from_node(neurons, neuron_layer, neuron_id) :: {:ok, {neuron_id, connections_from_node}}
  def get_random_inbound_connections_from_node(neurons, neuron_layer, neuron_id) do
    {:ok, neuron} = get_neuron(neurons, neuron_layer, neuron_id)
    {from_node_id, connections} = Enum.random(neuron.inbound_connections)
    {:ok, {from_node_id, connections}}
  end

  @spec find_neuron_layer(neuron_id, {neuron_layer, neuron_layer_structs}) :: neuron_layer
  def find_neuron_layer(neuron_id, {layer, neuron_structs}) do
    case Map.has_key?(neuron_structs, neuron_id) do
      true -> layer
      false -> nil
    end
  end

  @spec find_neuron_layer(neurons, neuron_id) :: {:ok, neuron_layer}
  def find_neuron_layer(neurons, neuron_id) do
      case Enum.find_value(neurons, nil, &find_neuron_layer(neuron_id, &1)) do
        nil -> {:error, "Neuron id #{inspect neuron_id} is not present in neurons #{inspect neurons}"}
        layer ->
          {:ok, layer}
      end
  end

  defp remove_outbound_connection_from_connections(outbound_connections, to_node_id, connection_id) do
    outbound_connections = Map.delete(outbound_connections, {to_node_id, connection_id})
    outbound_connections
  end

  @spec remove_outbound_connection(neurons, neuron_layer, neuron_id, neuron_id, connection_id) :: {:ok, neurons}
  def remove_outbound_connection(neurons, from_neuron_layer, from_neuron_id, to_node_id, connection_id) do
    {:ok, from_neuron} = get_neuron(neurons, from_neuron_layer, from_neuron_id)
    from_neuron_outbound_connections = remove_outbound_connection_from_connections(from_neuron.outbound_connections, to_node_id, connection_id)
    from_neuron = %Neuron{from_neuron | outbound_connections: from_neuron_outbound_connections}
    {:ok, neurons} = update(neurons, from_neuron_layer, from_neuron_id, from_neuron)
    {:ok, neurons}
  end

  @spec remove_inbound_connection(neurons, neuron_id, neuron_layer, neuron_id, connection_id) :: {:ok, neurons}
  def remove_inbound_connection(neurons, from_node_id, to_neuron_layer, to_neuron_id, connection_id) do
    {:ok, to_neuron} = get_neuron(neurons, to_neuron_layer, to_neuron_id)
    {:ok, to_neuron_inbound_connections_with_removed} = NeuralNode.remove_inbound_connection(to_neuron.inbound_connections, from_node_id, connection_id)
    to_neuron = %Neuron{to_neuron | inbound_connections: to_neuron_inbound_connections_with_removed}
    {:ok, neurons} = update(neurons, to_neuron_layer, to_neuron_id, to_neuron)
    {:ok, neurons}
  end

  @spec disconnect_neurons(neurons, neuron_layer, neuron_id, neuron_layer, neuron_id, connection_id) :: {:ok, neurons}
  def disconnect_neurons(neurons, from_neuron_layer, from_neuron_id, to_neuron_layer, to_neuron_id, connection_id) do
    {:ok, neurons} = remove_inbound_connection(neurons, from_neuron_id, to_neuron_layer, to_neuron_id, connection_id)
    {:ok, neurons} = remove_outbound_connection(neurons, from_neuron_layer, from_neuron_id, to_neuron_id, connection_id)
    {:ok, neurons}
  end

  @spec add_inbound_connection(neurons, neuron_id, neuron_layer, neuron_id, weight) :: {:ok, {connection_id, neurons}}
  def add_inbound_connection(neurons, from_node_id, to_neuron_layer, to_neuron_id, weight) do
    {:ok, to_neuron} = get_neuron(neurons, to_neuron_layer, to_neuron_id)
    {:ok, {updated_inbound_connections, new_connection_id}} =
      NeuralNode.add_inbound_connection(to_neuron.inbound_connections, from_node_id, weight)
    to_neuron = %Neuron{to_neuron | inbound_connections: updated_inbound_connections}
    {:ok, neurons} = update(neurons, to_neuron_layer, to_neuron_id, to_neuron)
    {:ok, {new_connection_id, neurons}}
  end

  @spec add_outbound_connection_to_connections(outbound_connections, NeuralNode.node_id, connection_id) :: outbound_connections
  def add_outbound_connection_to_connections(outbound_connections, to_node_id, connection_id) do
    outbound_key = {to_node_id, connection_id}
    outbound_connections = Map.put(outbound_connections, outbound_key, nil)
    outbound_connections
  end

  @spec add_outbound_connection_to_connections(NeuralNode.node_id, connection_id) :: outbound_connections
  def add_outbound_connection_to_connections(to_node_id, connection_id) do
    add_outbound_connection_to_connections(Map.new, to_node_id, connection_id)
  end

  @spec add_outbound_connection(neurons, neuron_layer, neuron_id, NeuralNode.node_id, connection_id) :: {:ok, neurons}
  def add_outbound_connection(neurons, from_neuron_layer, from_neuron_id, to_node_id, connection_id) do
    {:ok, from_neuron} = get_neuron(neurons, from_neuron_layer, from_neuron_id)
    updated_outbound_connections = add_outbound_connection_to_connections(from_neuron.outbound_connections, to_node_id, connection_id)
    from_neuron = %Neuron{from_neuron | outbound_connections: updated_outbound_connections}
    {:ok, neurons} = update(neurons, from_neuron_layer, from_neuron_id, from_neuron)
    {:ok, neurons}
  end

  @spec connect_neurons(neurons, neuron_layer, neuron_id, neuron_layer, neuron_id, weight) :: {:ok, neurons}
  def connect_neurons(neurons, from_neuron_layer, from_neuron_id, to_neuron_layer, to_neuron_id, weight) do
    {:ok, {connection_id, neurons}} = add_inbound_connection(neurons, from_neuron_id, to_neuron_layer, to_neuron_id, weight)
    {:ok, neurons} = add_outbound_connection(neurons, from_neuron_layer, from_neuron_id, to_neuron_id, connection_id)
    {:ok, neurons}
  end

  @spec start_link(neuron) :: {:ok, pid}
  def start_link(neuron) do
    case neuron.registry_func do
      nil ->
        GenServer.start_link(Neuron, neuron)
      reg_func ->
        neuron_name = reg_func.(neuron.neuron_id)
        GenServer.start_link(Neuron, neuron, name: neuron_name)
    end
  end

  @spec apply_weight_to_synapse(synapse, weight) :: synapse
  def apply_weight_to_synapse(synapse, inbound_connection_weight) do
    weighted_value = synapse.value * inbound_connection_weight
    %Synapse{synapse | value: weighted_value}
  end

  @spec send_synapse_to_outbound_connection(synapse, neuron_id, nil) :: :ok
  def send_synapse_to_outbound_connection(synapse, neuron_id, nil) do
    :ok = GenServer.cast(neuron_id, {:receive_synapse, synapse})
    :ok
  end

  @spec send_synapse_to_outbound_connection(synapse, neuron_id, registry_func) :: :ok
  def send_synapse_to_outbound_connection(synapse, outbound_neuron_id, registry_func) do
    outbound_id_with_via = registry_func.(outbound_neuron_id)
    :ok = GenServer.cast(outbound_id_with_via, {:receive_synapse, synapse})
    :ok
  end

  @spec send_output_value_to_outbound_connections(neuron_id, output_value, outbound_connections, registry_func) :: :ok
  def send_output_value_to_outbound_connections(from_neuron_id, output_value, outbound_connections, registry_func) do
    process_connection =
    (fn {to_node_pid, connection_id} ->
      synapse_to_send =
        %Synapse{
          connection_id: connection_id,
          from_node_id: from_neuron_id,
          value: output_value
        }
      send_synapse_to_outbound_connection(synapse_to_send, to_node_pid, registry_func)
    end)
    Enum.each(outbound_connections, process_connection)
  end

  @spec calculate_output_value(barrier, activation_function, bias) :: output_value
  def calculate_output_value(full_barrier, activation_function, bias) do
    get_synapse_value =
    (fn {_, synapse} ->
      synapse.value
    end)

    add_bias =
    fn synapse_sum ->
      case bias do
        nil -> synapse_sum
        bias ->
          synapse_sum + bias
      end
    end

    Enum.map(full_barrier, get_synapse_value)
    |> Enum.sum
    |> add_bias.()
    |> activation_function.()
  end

  @spec handle_cast({:receive_synapse, synapse}, neuron) :: {:noreply, neuron}
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
      case NeuralNode.is_barrier_full?(updated_barrier, state.inbound_connections) do
        true ->
          {_activation_function_id, activation_function} = state.activation_function
          output_value = calculate_output_value(updated_barrier, activation_function, state.bias)
          outbound_connections = Map.keys(state.outbound_connections)
          send_output_value_to_outbound_connections(state.neuron_id, output_value, outbound_connections, state.registry_func)
          updated_inbound_connections = process_learning_for_neuron(state.learning_function, state.inbound_connections, updated_barrier, output_value)
          %Neuron{state |
                  barrier: Map.new(),
                  inbound_connections: updated_inbound_connections
          }
        false ->
          %Neuron{state |
                  barrier: updated_barrier
                 }
      end
    {:noreply, updated_state}
  end

  @spec handle_call({:receive_blank_synapse, synapse}, pid, neuron) :: {:reply, :ok, neuron}
  def handle_call({:receive_blank_synapse, synapse}, _from, state) do
    updated_barrier =
      Map.put(state.barrier, {synapse.from_node_id, synapse.connection_id}, synapse)
    updated_state =
      %Neuron{state |
              barrier: updated_barrier
             }
    {:reply, :ok, updated_state}
  end

  defp process_learning_function({:hebbian, learning_coefficient}, old_weight, weighted_inbound_synapse, outbound_synapse) do
    unweighted_inbound_synapse = weighted_inbound_synapse / old_weight
    old_weight + learning_coefficient * unweighted_inbound_synapse * outbound_synapse
  end

  defp process_learning_function_for_connections_from_node(_learning_function, [], _weighted_inbound_synapse, _outbound_synapse, connections_from_node) do
    connections_from_node
  end

  defp process_learning_function_for_connections_from_node(learning_function, [{connection_id, old_weight} | remaining_connections], get_weighted_inbound_synapse, outbound_synapse, new_connections_from_node) do
    weighted_inbound_synapse = get_weighted_inbound_synapse.(connection_id)
    new_weight = process_learning_function(learning_function, old_weight, weighted_inbound_synapse, outbound_synapse)
    new_connections_from_node =
      Map.put(new_connections_from_node, connection_id, new_weight)
    process_learning_function_for_connections_from_node(learning_function, remaining_connections, get_weighted_inbound_synapse, outbound_synapse, new_connections_from_node)
  end

  defp process_learning_and_update_inbound_connections(_learning_function, [], _full_barrier, _outbound_synapse, new_inbound_connections) do
    new_inbound_connections
  end

  defp process_learning_and_update_inbound_connections(learning_function, [{node_id, connections_from_node} | remaining_inbound_connections], full_barrier, outbound_synapse, new_inbound_connections) do
    get_weighted_inbound_synapse = fn connection_id ->
      synapse = Map.get(full_barrier, {node_id, connection_id})
      synapse.value
    end
    updated_connections_from_node =
      process_learning_function_for_connections_from_node(learning_function, Map.to_list(connections_from_node), get_weighted_inbound_synapse, outbound_synapse, Map.new())
    new_inbound_connections =
      Map.put(new_inbound_connections, node_id, updated_connections_from_node)
    process_learning_and_update_inbound_connections(learning_function, remaining_inbound_connections, full_barrier, outbound_synapse, new_inbound_connections)
  end

  @spec process_learning_for_neuron(nil, inbound_connections, barrier, synapse) :: inbound_connections
  def process_learning_for_neuron(nil, inbound_connections, _full_barrier, _outbound_synapse) do
    inbound_connections
  end

  @spec process_learning_for_neuron(learning_function, inbound_connections, barrier, synapse) :: inbound_connections
  def process_learning_for_neuron(learning_function, inbound_connections, full_barrier, outbound_synapse) do
    process_learning_and_update_inbound_connections(learning_function, Map.to_list(inbound_connections), full_barrier, outbound_synapse, Map.new())
  end

  defp count_neurons_in_layer({_neuron_layer, neuron_structs}) do
    Enum.count(neuron_structs)
  end

  @spec count_total_neurons(neurons) :: Integer
  def count_total_neurons(neurons) do
    Enum.map(neurons, &count_neurons_in_layer/1)
    |> Enum.sum
  end

end
