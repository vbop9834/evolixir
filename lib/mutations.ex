defmodule MutationProperties do
  defstruct sensors: [],
    neurons: Map.new(),
    actuators: [],
    activation_functions: Map.new(),
    mutation: nil
end
defmodule Mutations do

  defp add_bias(neurons) do
    add_bias = fn neuron_struct ->
      case neuron_struct.bias do
        nil ->
          new_bias = :random.uniform()
          %{neuron_struct | bias: new_bias}
        _x -> :bias_already_exists
      end
    end
    {random_layer, random_structs} = Enum.random(neurons)
    {random_neuron_id, random_neuron} = Enum.random(random_structs)
    maybe_updated_neuron = add_bias.(random_neuron)
    case maybe_updated_neuron do
      :bias_already_exists -> :bias_already_exists
      updated_neuron ->
        updated_layer_neurons =
          Map.put(random_structs, random_neuron_id, updated_neuron)
        Map.put(neurons, random_layer, updated_layer_neurons)
    end
  end


  defp mutate_activation_function(neurons, activation_functions) do
    {random_layer, random_structs} = Enum.random(neurons)
    {random_neuron_id, random_neuron} = Enum.random(random_structs)
    activation_function_with_id = Enum.random(activation_functions)
    updated_neuron = %Neuron{random_neuron |
                             activation_function: activation_function_with_id
                            }
    updated_layer_neurons =
      Map.put(random_structs, random_neuron_id, updated_neuron)
    Map.put(neurons, random_layer, updated_layer_neurons)
  end

  defp remove_bias(neurons) do
    remove_bias = fn neuron_struct ->
      case neuron_struct.bias do
        nil -> :neuron_has_no_bias
        _x -> %{neuron_struct | bias: nil}
      end
    end
    {random_layer, random_structs} = Enum.random(neurons)
    {random_neuron_id, random_neuron} = Enum.random(random_structs)
    maybe_updated_neuron = remove_bias.(random_neuron)
    case maybe_updated_neuron do
      :neuron_has_no_bias -> :neuron_has_no_bias
      updated_neuron ->
        updated_layer_neurons =
          Map.put(random_structs, random_neuron_id, updated_neuron)
        Map.put(neurons, random_layer, updated_layer_neurons)
    end
  end

  defp mutate_weights(_probability_of_mutating, [], return_inbound_connections) do
    return_inbound_connections
  end

  defp mutate_weights(probability_of_mutating, [{connection_id, old_weight} | remaining_connections], new_inbound_connections) do
    case :random.uniform() <= probability_of_mutating do
      true ->
        min_weight_possible = -1.0 * (:math.pi / 2.0)
        max_weight_possible = :math.pi / 2.0
        new_weight = :random.uniform() * (max_weight_possible - min_weight_possible) + min_weight_possible
        updated_inbound_connections = Map.put(new_inbound_connections, connection_id, new_weight)
        mutate_weights(probability_of_mutating, remaining_connections, updated_inbound_connections)
      false ->
        updated_inbound_connections = Map.put(new_inbound_connections, connection_id, old_weight)
        mutate_weights(probability_of_mutating, remaining_connections, updated_inbound_connections)
    end
  end

  defp mutate_weights(neurons) do
    {random_layer, random_structs} = Enum.random(neurons)
    {random_neuron_id, random_neuron} = Enum.random(random_structs)
    {from_node_id, from_node_connections} = Enum.random(random_neuron.inbound_connections)
    probability_of_mutating = 1.0/:math.sqrt(Enum.count(from_node_connections))
    updated_connections_from_node = mutate_weights(probability_of_mutating, Map.to_list(from_node_connections), Map.new())
    updated_inbound_connections = Map.put(random_neuron.inbound_connections, from_node_id, updated_connections_from_node)
    updated_neuron = %Neuron{random_neuron |
                             inbound_connections: updated_inbound_connections
                            }
    updated_layer_neurons =
      Map.put(random_structs, random_neuron_id, updated_neuron)
    Map.put(neurons, random_layer, updated_layer_neurons)
  end

  defp reset_weights([], return_inbound_connections) do
    return_inbound_connections
  end

  defp reset_weights([{connection_id, _old_weight} | remaining_connections], new_inbound_connections) do
    min_weight_possible = -1.0 * (:math.pi / 2.0)
    max_weight_possible = :math.pi / 2.0
    new_weight = :random.uniform() * (max_weight_possible - min_weight_possible) + min_weight_possible
    updated_inbound_connections = Map.put(new_inbound_connections, connection_id, new_weight)
    reset_weights(remaining_connections, updated_inbound_connections)
  end

  defp reset_weights(neurons) do
    {random_layer, random_structs} = Enum.random(neurons)
    {random_neuron_id, random_neuron} = Enum.random(random_structs)
    {from_node_id, from_node_connections} = Enum.random(random_neuron.inbound_connections)
    updated_connections_from_node = reset_weights(Map.to_list(from_node_connections), Map.new())
    updated_inbound_connections = Map.put(random_neuron.inbound_connections, from_node_id, updated_connections_from_node)
    updated_neuron = %Neuron{random_neuron |
                             inbound_connections: updated_inbound_connections
                            }
    updated_layer_neurons =
      Map.put(random_structs, random_neuron_id, updated_neuron)
    Map.put(neurons, random_layer, updated_layer_neurons)
  end

  defp add_inbound_connection(neurons) do
    {random_target_layer, random_target_structs} = Enum.random(neurons)
    {random_target_neuron_id, random_target_neuron} = Enum.random(random_target_structs)
    {random_from_layer, random_from_structs} = Enum.random(neurons)
    {random_from_neuron_id, _random_from_neuron} = Enum.random(random_from_structs)
    min_weight_possible = -1.0 * (:math.pi / 2.0)
    max_weight_possible = :math.pi / 2.0
    new_connection_weight = :random.uniform() * (max_weight_possible - min_weight_possible) + min_weight_possible
    {updated_target_inbound_connections, new_connection_id} = NeuralNode.add_inbound_connection(random_target_neuron.inbound_connections, random_from_neuron_id, new_connection_weight)
    updated_target_neuron = %Neuron{random_target_neuron |
                                    inbound_connections: updated_target_inbound_connections
                                   }
    updated_target_layer = Map.put(random_target_structs, random_target_neuron_id, updated_target_neuron)
    updated_neurons_with_inbound = Map.put(neurons, random_target_layer, updated_target_layer)
    from_layer_structs = Map.get(updated_neurons_with_inbound, random_from_layer)
    random_from_neuron = Map.get(from_layer_structs, random_from_neuron_id)
    updated_from_outbound_connections = NeuralNode.add_outbound_connection(random_from_neuron.outbound_connections, random_target_neuron_id, new_connection_id)
    updated_from_neuron = %Neuron{random_from_neuron |
                                  outbound_connections: updated_from_outbound_connections
                                 }
    updated_from_layer = Map.put(random_from_structs, random_from_neuron_id, updated_from_neuron)
    Map.put(neurons, random_from_layer, updated_from_layer)
  end

  def mutate(%MutationProperties{
        mutation: :add_bias,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators
             }) do
    case add_bias(neurons) do
      :bias_already_exists -> :mutation_did_not_occur
      updated_neurons -> {sensors, updated_neurons, actuators}
    end
  end

  def mutate(%MutationProperties{
        mutation: :mutate_activation_function,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators,
        activation_functions: activation_functions
             }) do
    updated_neurons = mutate_activation_function(neurons, activation_functions)
    {sensors, updated_neurons, actuators}
  end

  def mutate(%MutationProperties{
        mutation: :remove_bias,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators
             }) do
    case remove_bias(neurons) do
      :neuron_has_no_bias -> :mutation_did_not_occur
      updated_neurons -> {sensors, updated_neurons, actuators}
    end
  end

  def mutate(%MutationProperties{
        mutation: :mutate_weights,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators
             }) do
    updated_neurons = mutate_weights(neurons)
    {sensors, updated_neurons, actuators}
  end

  def mutate(%MutationProperties{
        mutation: :reset_weights,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators
             }) do
    updated_neurons = reset_weights(neurons)
    {sensors, updated_neurons, actuators}
  end

  def mutate(%MutationProperties{
        mutation: :add_inbound_connection,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators
             }) do
    updated_neurons = add_inbound_connection(neurons)
    {sensors, updated_neurons, actuators}
  end

end
