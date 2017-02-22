defmodule StochasticHillClimber do

  defp perturb_connections_from_node([], _probability_of_weight_perrrubing, perturbed_connections_from_node) do
    perturbed_connections_from_node
  end

  defp perturb_connections_from_node([{connection_id, old_weight} | remaining_connections_from_node], probability_of_weight_perturbing, perturbed_connections_from_node) do
    case :random.uniform() > probability_of_weight_perturbing do
      true ->
        new_weight = Mutations.get_random_weight()
        perturbed_connections_from_node = Map.put(perturbed_connections_from_node, connection_id, new_weight)
        perturb_connections_from_node(remaining_connections_from_node, probability_of_weight_perturbing, perturbed_connections_from_node)
      false ->
        perturbed_connections_from_node = Map.put(perturbed_connections_from_node, connection_id, old_weight)
        perturb_connections_from_node(remaining_connections_from_node, probability_of_weight_perturbing, perturbed_connections_from_node)
    end
  end

  defp perturb_connections_from_node(connections_from_node, probability_of_weight_perturbing) do
    perturb_connections_from_node(Map.to_list(connections_from_node), probability_of_weight_perturbing, Map.new())
  end

  defp perturb_inbound_connections([], _probability_of_weight_perturbing, perturbed_inbound_connections) do
    perturbed_inbound_connections
  end

  defp perturb_inbound_connections([{from_node_id, connections_from_node} | remaining_inbound_connections], probability_of_weight_perturbing, perturbed_inbound_connections) do
    connections_from_node = perturb_connections_from_node(connections_from_node, probability_of_weight_perturbing)
    perturbed_inbound_connections = Map.put(perturbed_inbound_connections, from_node_id, connections_from_node)
    perturb_inbound_connections(remaining_inbound_connections, probability_of_weight_perturbing, perturbed_inbound_connections)
  end

  defp perturb_inbound_connections(inbound_connections, probability_of_weight_perturbing) do
    perturb_inbound_connections(Map.to_list(inbound_connections), probability_of_weight_perturbing, Map.new())
  end

  defp count_total_inbound_connections([], total_count) do
    total_count
  end

  defp count_total_inbound_connections([{_from_node_id, connections_from_node} | remaining_connections], total_count) do
    total_count = Enum.count(connections_from_node) + total_count
    count_total_inbound_connections(remaining_connections, total_count)
  end

  defp count_total_inbound_connections(neuron_struct) do
    count_total_inbound_connections(Map.to_list(neuron_struct.inbound_connections), 0)
  end

  defp perturb_weights_in_neural_layer([], _probability_of_neuron_perturbing, perturbed_layer) do
    perturbed_layer
  end

  defp perturb_weights_in_neural_layer([{neuron_id, neuron_struct} | remaining_neurons], probability_of_neuron_perturbing, perturbed_layer) do
    case :random.uniform() > probability_of_neuron_perturbing do
      true ->
        #perturb
        total_number_of_weights = count_total_inbound_connections(neuron_struct)
        probability_of_weight_perturbing = 1 / :math.sqrt(total_number_of_weights)
        inbound_connections = perturb_inbound_connections(neuron_struct.inbound_connections, probability_of_weight_perturbing)
        neuron_struct = %Neuron{neuron_struct |
                                inbound_connections: inbound_connections
                               }
        perturbed_layer = Map.put(perturbed_layer, neuron_id, neuron_struct)
        perturb_weights_in_neural_layer(remaining_neurons, probability_of_neuron_perturbing, perturbed_layer)
      false ->
        perturbed_layer = Map.put(perturbed_layer, neuron_id, neuron_struct)
        perturb_weights_in_neural_layer(remaining_neurons, probability_of_neuron_perturbing, perturbed_layer)
    end
  end

  defp perturb_weights_in_neural_layer(neuron_layer, probability_of_neuron_perturbing) do
    perturb_weights_in_neural_layer(Map.to_list(neuron_layer), probability_of_neuron_perturbing, Map.new())
  end

  def perturb_weights_in_neurons([], _probability_of_mutating, perturbed_neural_network) do
    perturbed_neural_network
  end

  def perturb_weights_in_neurons([{neuron_layer_number, neuron_layer} | remaining_layers], probability_of_neuron_perturbing, perturbed_neural_network) do
    perturbed_layer = perturb_weights_in_neural_layer(neuron_layer, probability_of_neuron_perturbing)
    perturbed_neural_network = Map.put(perturbed_neural_network, neuron_layer_number, perturbed_layer)
    perturb_weights_in_neurons(remaining_layers, probability_of_neuron_perturbing, perturbed_neural_network)
  end

  def perturb_weights_in_neurons(neurons, probability_of_neuron_perturbing) do
    perturb_weights_in_neurons(Map.to_list(neurons), probability_of_neuron_perturbing, Map.new())
  end

  def perturb_weights_in_neural_network({sensors, neurons, actuators}, max_attempts_possible) do
    total_number_of_neurons = Neuron.count_total_neurons(neurons)
    #Things to think about
    #Should sensors and actuators be counted?
    neural_network_size = Enum.count(sensors) + total_number_of_neurons + Enum.count(actuators)

    probability_of_neuron_perturbing = 1/:math.sqrt(neural_network_size)

    network_size_max_attempts =
      :math.sqrt(total_number_of_neurons)
      |> round

    max_attempts =
      case max_attempts_possible < network_size_max_attempts do
        true ->
          max_attempts_possible
        false ->
          network_size_max_attempts
      end

    Enum.map([1..max_attempts], fn perturb_id ->
      neurons = perturb_weights_in_neurons(neurons, probability_of_neuron_perturbing)
      {perturb_id, {sensors, neurons, actuators}}
    end)
  end



end
