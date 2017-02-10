defmodule MutationProperties do
  defstruct sensors: Map.new(),
    neurons: Map.new(),
    actuators: Map.new(),
    activation_functions: Map.new(),
    sync_functions: Map.new(),
    mutation: nil
end
defmodule Mutations do

  defp get_random_weight() do
    min_weight_possible = -1.0 * (:math.pi / 2.0)
    max_weight_possible = :math.pi / 2.0
    :random.uniform() * (max_weight_possible - min_weight_possible) + min_weight_possible
  end

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
        new_weight = get_random_weight()
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
    updated_from_outbound_connections = Neuron.add_outbound_connection(random_from_neuron.outbound_connections, random_target_neuron_id, new_connection_id)
    updated_from_neuron = %Neuron{random_from_neuron |
                                  outbound_connections: updated_from_outbound_connections
                                 }
    updated_from_layer = Map.put(random_from_structs, random_from_neuron_id, updated_from_neuron)
    Map.put(neurons, random_from_layer, updated_from_layer)
  end

  defp get_highest_neuron_id_in_structs(highest_neuron_id, []) do
    highest_neuron_id
  end

  defp get_highest_neuron_id_in_structs(highest_neuron_id_so_far, [neuron_id | remaining_neurons]) do
    case neuron_id > highest_neuron_id_so_far do
      true -> get_highest_neuron_id_in_structs(neuron_id, remaining_neurons)
      false -> get_highest_neuron_id_in_structs(highest_neuron_id_so_far, remaining_neurons)
    end
  end

  defp get_new_neuron_id(highest_neuron_id, []) do
    highest_neuron_id + 1
  end

  defp get_new_neuron_id(highest_neuron_id_so_far, [{_layer, neuron_structs} | remaining_layers]) do
    neuron_structs_list = Map.keys(neuron_structs)
    highest_neuron_id = get_highest_neuron_id_in_structs(highest_neuron_id_so_far, neuron_structs_list)
    get_new_neuron_id(highest_neuron_id, remaining_layers)
  end

  defp add_neuron(neurons, activation_functions) do
    {new_neuron_layer, _structs} = Enum.random(neurons)
    new_neuron_id = get_new_neuron_id(0, Map.to_list(neurons))

    {random_B_layer, random_B_structs} = Enum.random(neurons)
    {random_B_neuron_id, random_B_neuron} = Enum.random(random_B_structs)
    new_neuron_to_B_weight = get_random_weight()
    {updated_B_inbound_connections, new_neuron_to_B_connection_id} = NeuralNode.add_inbound_connection(random_B_neuron.inbound_connections, new_neuron_id, new_neuron_to_B_weight)
    updated_B_neuron = %Neuron{random_B_neuron |
                               inbound_connections: updated_B_inbound_connections
                              }
    updated_B_layer = Map.put(random_B_structs, random_B_neuron_id, updated_B_neuron)
    neurons_updated_with_B = Map.put(neurons, random_B_layer, updated_B_layer)

    {random_A_layer, random_A_structs} = Enum.random(neurons_updated_with_B)
    {random_A_neuron_id, random_A_neuron} = Enum.random(random_A_structs)

    neuron_A_to_new_weight = get_random_weight()
    {new_neuron_inbound_connections, neuron_A_to_new_neuron_connection_id} = NeuralNode.add_inbound_connection(random_A_neuron_id, neuron_A_to_new_weight)

    updated_neuron_A_outbound_connections = Neuron.add_outbound_connection(random_A_neuron.outbound_connections, new_neuron_id, neuron_A_to_new_neuron_connection_id)
    updated_neuron_A = %Neuron{random_A_neuron |
                               outbound_connections: updated_neuron_A_outbound_connections
                              }
    updated_A_layer = Map.put(random_A_structs, random_A_neuron_id, updated_neuron_A)
    neurons_updated_with_A_and_B = Map.put(neurons_updated_with_B, random_A_layer, updated_A_layer)

    new_neuron_outbound_connections = Neuron.add_outbound_connection(random_B_neuron_id, new_neuron_to_B_connection_id)

    activation_function = Enum.random(activation_functions)
    new_neuron = %Neuron{
      neuron_id: new_neuron_id,
      outbound_connections: new_neuron_outbound_connections,
      inbound_connections: new_neuron_inbound_connections,
      bias: nil,
      activation_function: activation_function
    }

    new_neuron_layer_structs = Map.get(neurons_updated_with_A_and_B, new_neuron_layer)

    updated_new_neuron_layer = Map.put(new_neuron_layer_structs, new_neuron_id, new_neuron)
    neurons_updated_with_A_B_and_new = Map.put(neurons_updated_with_A_and_B, new_neuron_layer, updated_new_neuron_layer)
    neurons_updated_with_A_B_and_new
  end

  defp add_neuron_outsplice(neurons, actuators, activation_functions) do
    new_neuron_id = get_new_neuron_id(0, Map.to_list(neurons))

    {random_A_layer, random_A_structs} = Enum.random(neurons)
    {random_A_neuron_id, random_A_neuron} = Enum.random(random_A_structs)
    {{node_B_id, neuron_A_to_B_connection_id}, nil} = Enum.random(random_A_neuron.outbound_connections)
    {node_B_type, node_B_struct} =
      case Map.has_key?(actuators, node_B_id) do
        true ->
          actuator_struct = Map.get(actuators, node_B_id)
          {:actuator, actuator_struct}
        false ->
          node_B_layer = NeuralNode.find_neuron_layer(node_B_id, neurons)
          neuron_struct =
            Map.get(neurons, node_B_layer)
            |> (fn neuron_structs -> Map.get(neuron_structs, node_B_id) end).()

          {{:neuron, node_B_layer}, neuron_struct}
      end
    node_B_inbound_connections_with_removed_connection =
      NeuralNode.remove_inbound_connection(node_B_struct.inbound_connections, random_A_neuron_id, neuron_A_to_B_connection_id)

    new_neuron_to_B_weight = get_random_weight()
    {updated_B_inbound_connections, new_neuron_to_B_connection_id} =
      NeuralNode.add_inbound_connection(node_B_inbound_connections_with_removed_connection, new_neuron_id, new_neuron_to_B_weight)
    updated_node_B = %{node_B_struct |
                       inbound_connections: updated_B_inbound_connections
                      }
    {node_B_layer, neurons, actuators} =
      case node_B_type do
        :actuator ->
          updated_actuators =
            Map.put(actuators, node_B_id, updated_node_B)
          {:actuator, neurons, updated_actuators}
        {:neuron, node_B_layer} ->
          b_layer_structs =
            Map.get(neurons, node_B_layer)
          updated_B_layer =
            Map.put(b_layer_structs, node_B_id, updated_node_B)
          updated_neurons =
            Map.put(neurons, node_B_layer, updated_B_layer)
          {node_B_layer, updated_neurons, actuators}
      end

    neuron_A_to_new_weight = get_random_weight()
    {new_neuron_inbound_connections, neuron_A_to_new_neuron_connection_id} =
      NeuralNode.add_inbound_connection(random_A_neuron_id, neuron_A_to_new_weight)

    neuron_A_outbound_connections_with_removed_connection =
      Neuron.remove_outbound_connection(random_A_neuron.outbound_connections, node_B_id, neuron_A_to_B_connection_id)

    updated_neuron_A_outbound_connections = Neuron.add_outbound_connection(neuron_A_outbound_connections_with_removed_connection, new_neuron_id, neuron_A_to_new_neuron_connection_id)
    updated_neuron_A = %Neuron{random_A_neuron |
                               outbound_connections: updated_neuron_A_outbound_connections
                              }
    updated_A_layer =
      Map.put(random_A_structs, random_A_neuron_id, updated_neuron_A)
    neurons_updated_with_A_and_B =
      Map.put(neurons, random_A_layer, updated_A_layer)

    new_neuron_outbound_connections =
      Neuron.add_outbound_connection(node_B_id, new_neuron_to_B_connection_id)

    new_neuron_layer =
      case node_B_layer do
        :actuator -> random_A_layer + 1
        node_B_layer ->
          (random_A_layer + node_B_layer) / 2
      end
    activation_function = Enum.random(activation_functions)
    new_neuron = %Neuron{
      neuron_id: new_neuron_id,
      outbound_connections: new_neuron_outbound_connections,
      inbound_connections: new_neuron_inbound_connections,
      bias: nil,
      activation_function: activation_function
    }

    new_neuron_layer_structs =
      Map.get(neurons_updated_with_A_and_B, new_neuron_layer, Map.new())

    updated_new_neuron_layer =
      Map.put(new_neuron_layer_structs, new_neuron_id, new_neuron)
    neurons_updated_with_A_B_and_new =
      Map.put(neurons_updated_with_A_and_B, new_neuron_layer, updated_new_neuron_layer)
    {neurons_updated_with_A_B_and_new, actuators}
  end

  defp add_neuron_insplice(neurons, sensors, activation_functions) do
    new_neuron_id = get_new_neuron_id(0, Map.to_list(neurons))

    {random_A_layer, random_A_structs} = Enum.random(neurons)
    {random_A_neuron_id, random_A_neuron} = Enum.random(random_A_structs)
    {node_B_id, from_node_B_connections} = Enum.random(random_A_neuron.inbound_connections)
    {node_B_to_A_connection_id, _weight} = Enum.random(from_node_B_connections)

    neuron_A_inbound_connections_with_removed =
      NeuralNode.remove_inbound_connection(random_A_neuron.inbound_connections, node_B_id, node_B_to_A_connection_id)
    random_A_neuron =
      %Neuron{random_A_neuron |
              inbound_connections: neuron_A_inbound_connections_with_removed
             }

    activation_function = Enum.random(activation_functions)
    new_neuron = %Neuron{
      neuron_id: new_neuron_id,
      bias: nil,
      activation_function: activation_function
    }
    new_neuron_to_A_weight = get_random_weight()
    {new_neuron, updated_A_neuron} =
      Neuron.connect_neurons(new_neuron, random_A_neuron, new_neuron_to_A_weight)
    updated_A_layer =
      Map.put(random_A_structs, random_A_neuron_id, updated_A_neuron)
    neurons =
      Map.put(neurons, random_A_layer, updated_A_layer)

    {updated_sensors, updated_neurons} =
      case Map.has_key?(sensors, node_B_id) do
        true ->
          sensor = Map.get(sensors, node_B_id)
          sensor_outbound_connections_with_removed =
            Sensor.remove_outbound_connection(sensor.outbound_connections, random_A_neuron_id, node_B_to_A_connection_id)
          sensor_with_removed_connnection = %Sensor{sensor |
                           outbound_connections: sensor_outbound_connections_with_removed
                          }
          sensor_to_new_neuron_weight = get_random_weight()
          {updated_sensor, new_neuron} =
            Sensor.connect_to_neuron(sensor_with_removed_connnection, new_neuron, sensor_to_new_neuron_weight)
          updated_sensors =
            Map.put(sensors, node_B_id, updated_sensor)
          new_neuron_layer = random_A_layer/2
          layer_structs = Map.get(neurons, new_neuron_layer, Map.new())
          updated_layer_structs =
            Map.put(layer_structs, new_neuron_id, new_neuron)
          updated_neurons =
            Map.put(neurons, new_neuron_layer, updated_layer_structs)
          {updated_sensors, updated_neurons}
        false ->
          node_B_layer =
            NeuralNode.find_neuron_layer(node_B_id, neurons)
          node_B_layer_structs =
            Map.get(neurons, node_B_layer)
          neuron_B =
            Map.get(node_B_layer_structs, node_B_id)
          neuron_B_outbound_connections_with_removed =
            Neuron.remove_outbound_connection(neuron_B.outbound_connections, random_A_neuron_id, node_B_to_A_connection_id)
          neuron_B = %Neuron{neuron_B |
                             outbound_connections: neuron_B_outbound_connections_with_removed
                            }
          neuron_to_new_neuron_weight = get_random_weight()
          {updated_neuron_B, new_neuron} =
            Neuron.connect_neurons(neuron_B, new_neuron, neuron_to_new_neuron_weight)

          new_neuron_layer = (random_A_layer + node_B_layer) / 2
          updated_B_structs =
            Map.put(node_B_layer_structs, node_B_id, updated_neuron_B)
          neurons_updated_with_B =
            Map.put(neurons, node_B_layer, updated_B_structs)
          new_layer_structs =
            Map.get(neurons_updated_with_B, new_neuron_layer, Map.new())
          updated_layer_structs =
            Map.put(new_layer_structs, new_neuron_id, new_neuron)
          updated_neurons =
            Map.put(neurons_updated_with_B, new_neuron_layer, updated_layer_structs)
          {sensors, updated_neurons}
      end

    {updated_sensors, updated_neurons}
  end

  defp add_sensor_link(sensors, neurons) do
    {sensor_id, sensor} = Enum.random(sensors)
    case Enum.count(sensor.outbound_connections) >= sensor.maximum_vector_size do
      true ->
        :mutation_did_not_occur
      false ->
        {neuron_layer, neuron_structs} =
          Enum.random(neurons)
        {neuron_id, neuron} =
          Enum.random(neuron_structs)
        weight = get_random_weight()
        {updated_sensor, updated_neuron} =
          Sensor.connect_to_neuron(sensor, neuron, weight)
        sensors =
          Map.put(sensors, sensor_id, updated_sensor)
        updated_neuron_layer =
          Map.put(neuron_structs, neuron_id, updated_neuron)
        neurons =
          Map.put(neurons, neuron_layer, updated_neuron_layer)
        {sensors, neurons}
     end
  end

  defp add_actuator_link(neurons, actuators) do
    {actuator_id, actuator} = Enum.random(actuators)
    {neuron_layer, neuron_structs} =
      Enum.random(neurons)
    {neuron_id, neuron} =
      Enum.random(neuron_structs)
    {updated_neuron, updated_actuator} =
      Neuron.connect_to_actuator(neuron, actuator)
    actuators =
      Map.put(actuators, actuator_id, updated_actuator)
    updated_neuron_layer =
      Map.put(neuron_structs, neuron_id, updated_neuron)
    neurons =
      Map.put(neurons, neuron_layer, updated_neuron_layer)
    {neurons, actuators}
  end

  def add_sensor(sensors, neurons, sync_functions) do
    {neuron_layer, neuron_structs} =
      Enum.random(neurons)
    {neuron_id, neuron} =
      Enum.random(neuron_structs)

    case Enum.count(sensors) >= Enum.count(sync_functions) do
      true ->
        :mutation_did_not_occur
      false ->
        max_sensor_id =
          Map.keys(sensors)
          |> Enum.max
        new_sensor_id = max_sensor_id + 1
        sync_functions_used =
          Enum.map(sensors, fn {_sensor_id, sensor} ->
            case sensor.sync_function do
              {sync_function_id, _sync_function} -> sync_function_id
              sync_function_id -> sync_function_id
            end
          end)
        sync_functions_not_used =
          Enum.map(sync_functions, fn sync_function ->
            case sync_function do
              {sync_function_id, _sync_function} -> sync_function_id
              sync_function_id ->
                sync_function_id
            end
          end)
          |> (fn sync_function_ids -> sync_function_ids -- sync_functions_used end).()
        sync_function_id =
          Enum.random(sync_functions_not_used)
        new_sensor = %Sensor{
          sensor_id: new_sensor_id,
          sync_function: sync_function_id
        }

        weight = get_random_weight()
        {new_sensor, neuron} =
          Sensor.connect_to_neuron(new_sensor, neuron, weight)

        sensors =
          Map.put(sensors, new_sensor_id, new_sensor)

        updated_neuron_layer =
          Map.put(neuron_structs, neuron_id, neuron)
        neurons =
          Map.put(neurons, neuron_layer, updated_neuron_layer)

        {sensors, neurons}
    end
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

  def mutate(%MutationProperties{
        mutation: :add_outbound_connection,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators
             }) do
    updated_neurons = add_inbound_connection(neurons)
    {sensors, updated_neurons, actuators}
  end

  def mutate(%MutationProperties{
        mutation: :add_neuron,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators,
        activation_functions: activation_functions
             }) do
    updated_neurons = add_neuron(neurons, activation_functions)
    {sensors, updated_neurons, actuators}
  end

  def mutate(%MutationProperties{
        mutation: :add_neuron_outsplice,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators,
        activation_functions: activation_functions
             }) do
    {updated_neurons, updated_actuators} = add_neuron_outsplice(neurons, actuators, activation_functions)
    {sensors, updated_neurons, updated_actuators}
  end

  def mutate(%MutationProperties{
        mutation: :add_neuron_insplice,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators,
        activation_functions: activation_functions
             }) do
    {updated_sensors, updated_neurons} = add_neuron_insplice(neurons, sensors, activation_functions)
    {updated_sensors, updated_neurons, actuators}
  end

  def mutate(%MutationProperties{
        mutation: :add_sensor_link,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators
             }) do
    case add_sensor_link(sensors, neurons) do
      :mutation_did_not_occur -> :mutation_did_not_occur
      {updated_sensors, updated_neurons} ->
        {updated_sensors, updated_neurons, actuators}
    end
  end

  def mutate(%MutationProperties{
        mutation: :add_actuator_link,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators
             }) do
    {updated_neurons, updated_actuators} = add_actuator_link(neurons, actuators)
    {sensors, updated_neurons, updated_actuators}
  end

  def mutate(%MutationProperties{
        mutation: :add_sensor,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators,
        sync_functions: sync_functions
             }) do
    {updated_sensors, updated_neurons} = add_sensor(sensors, neurons, sync_functions)
    {updated_sensors, updated_neurons, actuators}
  end

end
