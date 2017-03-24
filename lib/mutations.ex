defmodule MutationProperties do
  defstruct sensors: Map.new(),
    neurons: Map.new(),
    actuators: Map.new(),
    activation_functions: Map.new(),
    sync_functions: Map.new(),
    actuator_functions: Map.new(),
    mutation: nil,
    learning_function: nil,
    get_node_id: nil
end
defmodule Mutations do
  require Logger

  @type neural_network :: {Sensor.sensors, Neuron.neurons, Actuator.actuators}

  def default_mutation_sequence do
    [
      :add_bias,
      :remove_bias,
      :mutate_activation_function,
      :mutate_weights,
      :reset_weights,
      :add_inbound_connection,
      :add_outbound_connection,
      :add_sensor,
      :add_neuron,
      :add_neuron_outsplice,
      :add_neuron_insplice,
      :add_actuator,
      :add_sensor_link,
      :add_actuator_link
    ]
  end

  def get_random_weight() do
    min_weight_possible = -1.0 * (:math.pi / 2.0)
    max_weight_possible = :math.pi / 2.0
    :random.uniform() * (max_weight_possible - min_weight_possible) + min_weight_possible
  end

  defp add_bias(neurons) do
    #Acquire a random neuron
    {:ok, {neuron_layer, neuron_id}} = Neuron.get_random_neuron(neurons)
    #Generate new bias
    new_bias = :random.uniform()
    #Change neuron to use new bias
    {:ok, neurons} = Neuron.change_bias(neurons, neuron_layer, neuron_id, new_bias)
    {:ok, neurons}
  end

  defp mutate_activation_function(neurons, activation_functions) do
    {:ok, {neuron_layer, neuron_id}} = Neuron.get_random_neuron(neurons)
    activation_function = Enum.random(activation_functions)
    {:ok, neurons} = Neuron.change_activation_function(neurons, neuron_layer, neuron_id, activation_function)
    {:ok, neurons}
  end

  defp remove_bias(neurons) do
    {:ok, {neuron_layer, neuron_id}}= Neuron.get_random_neuron(neurons)
    {:ok, neurons} = Neuron.remove_bias(neurons, neuron_layer, neuron_id)
    {:ok, neurons}
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
    {:ok, {neuron_layer, neuron_id}} = Neuron.get_random_neuron(neurons)
    {:ok, neuron} = Neuron.get_neuron(neurons, neuron_layer, neuron_id)
    {:ok, {from_node_id, from_node_connections}} = Neuron.get_random_inbound_connections_from_node(neurons, neuron_layer, neuron_id)
    probability_of_mutating = 1.0/:math.sqrt(Enum.count(from_node_connections))
    inbound_connections_from_node = mutate_weights(probability_of_mutating, Map.to_list(from_node_connections), Map.new())
    inbound_connections = Map.put(neuron.inbound_connections, from_node_id, inbound_connections_from_node)
    neuron = %Neuron{neuron | inbound_connections: inbound_connections}
    {:ok, neurons} = Neuron.update(neurons, neuron_layer, neuron_id, neuron)
    {:ok, neurons}
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
    {:ok, {neuron_layer, neuron_id}} = Neuron.get_random_neuron(neurons)
    {:ok, neuron} = Neuron.get_neuron(neurons, neuron_layer, neuron_id)
    {:ok, {from_node_id, from_node_connections}} = Neuron.get_random_inbound_connections_from_node(neurons, neuron_layer, neuron_id)
    inbound_connections_from_node = reset_weights(Map.to_list(from_node_connections), Map.new())
    inbound_connections = Map.put(neuron.inbound_connections, from_node_id, inbound_connections_from_node)
    neuron = %Neuron{neuron | inbound_connections: inbound_connections}
    {:ok, neurons} = Neuron.update(neurons, neuron_layer, neuron_id, neuron)
    {:ok, neurons}
  end

  defp add_inbound_connection(neurons) do
    #Acquire random neuron A
    {:ok, {neuron_A_layer, neuron_A_id}} = Neuron.get_random_neuron(neurons)
    #Acquire random neuron B
    {:ok, {neuron_B_layer, neuron_B_id}} = Neuron.get_random_neuron(neurons)
    #Connect neuron A to B
    weight = get_random_weight()
    {:ok, neurons} = Neuron.connect_neurons(neurons, neuron_A_layer, neuron_A_id, neuron_B_layer, neuron_B_id, weight)
    {:ok, neurons}
  end

  defp add_neuron(neurons, get_node_id, activation_functions, learning_function) do
    #Acquire random neuron A
    {:ok, {neuron_A_layer, neuron_A_id}} = Neuron.get_random_neuron(neurons)
    #Acquire random neuron B
    {:ok, {neuron_B_layer, neuron_B_id}} = Neuron.get_random_neuron(neurons)
    #Create new neuron
    new_neuron_layer = neuron_A_layer
    new_neuron_id = get_node_id.()
    activation_function = Enum.random(activation_functions)
    {:ok, neurons} = Neuron.create(neurons, new_neuron_layer, new_neuron_id, activation_function, learning_function)
    #Connect neuron A to new neuron
    neuron_A_to_new_weight = get_random_weight()
    {:ok, neurons} = Neuron.connect_neurons(neurons, neuron_A_layer, neuron_A_id, new_neuron_layer, new_neuron_id, neuron_A_to_new_weight)
    #Connect new neuron to neuron B
    new_neuron_to_B_weight = get_random_weight()
    {:ok, neurons} = Neuron.connect_neurons(neurons, new_neuron_layer, new_neuron_id, neuron_B_layer, neuron_B_id, new_neuron_to_B_weight)
    {:ok, neurons}
  end

  defp add_neuron_outsplice(neurons, actuators, get_node_id, activation_functions, learning_function) do
    #Acquire random neuron A
    {:ok, {neuron_A_layer, neuron_A_id}} = Neuron.get_random_neuron(neurons)
    #Acquire a random oubound connection from neuron A
    {:ok, {node_B_id, neuron_A_to_B_connection_id}} = Neuron.get_random_outbound_connection(neurons, neuron_A_layer, neuron_A_id)

    #Update neurons and actuators with the new neuron
    #By connecting A to New Neuron to B
    {neurons, actuators} =
      #Identify what Node B is
      case Map.has_key?(actuators, node_B_id) do
        true ->
          actuator_id = node_B_id
          #Disconnect neuron from actuator
          {:ok, {neurons, actuators}} = Actuator.disconnect_neuron_from_actuator(neurons, actuators, neuron_A_layer, neuron_A_id, actuator_id, neuron_A_to_B_connection_id)
          #Create the Neuron
          new_neuron_layer = neuron_A_layer + 1
          new_neuron_id = get_node_id.()
          activation_function = Enum.random(activation_functions)
          {:ok, neurons} = Neuron.create(neurons, new_neuron_layer, new_neuron_id, activation_function, learning_function)
          #Connect neuron A to new neuron
          neuron_A_to_new_neuron_weight = get_random_weight()
          {:ok, neurons} = Neuron.connect_neurons(neurons, neuron_A_layer, neuron_A_id, new_neuron_layer, new_neuron_id, neuron_A_to_new_neuron_weight)
          #Connect the new neuron to actuator B
          {:ok, {neurons, actuators}} = Actuator.connect_neuron_to_actuator(neurons, actuators, new_neuron_layer, new_neuron_id, actuator_id)
          {neurons, actuators}
        false ->
          neuron_B_id = node_B_id
          {:ok, neuron_B_layer} = Neuron.find_neuron_layer(neurons, neuron_B_id)
          #Disconnect neuron A from B
          {:ok, neurons} = Neuron.disconnect_neurons(neurons, neuron_A_layer, neuron_A_id, neuron_B_layer, neuron_B_id, neuron_A_to_B_connection_id)
          #Create the Neuron
          new_neuron_layer = (neuron_A_layer + neuron_B_layer) / 2
          new_neuron_id = get_node_id.()
          activation_function = Enum.random(activation_functions)
          {:ok, neurons} = Neuron.create(neurons, new_neuron_layer, new_neuron_id, activation_function, learning_function)
          #Connect neuron A to new neuron
          neuron_A_to_new_neuron_weight = get_random_weight()
          {:ok, neurons} = Neuron.connect_neurons(neurons, neuron_A_layer, neuron_A_id, new_neuron_layer, new_neuron_id, neuron_A_to_new_neuron_weight)
          #Connect the new neuron to neuron B
          new_neuron_to_B_weight = get_random_weight()
          {:ok, neurons} = Neuron.connect_neurons(neurons, new_neuron_layer, new_neuron_id, neuron_B_layer, neuron_B_id, new_neuron_to_B_weight)
          {neurons, actuators}
      end
    {:ok, {neurons, actuators}}
  end

  defp add_neuron_insplice(neurons, sensors, activation_functions, learning_function, get_node_id) do
    #Acquire random neuron B
    {:ok, {neuron_B_layer, neuron_B_id}} = Neuron.get_random_neuron(neurons)
    #Acquire random inbound connection for Neuron B
    {:ok, {node_A_id, node_A_to_B_connection_id, _weight}} = Neuron.get_random_inbound_connection(neurons, neuron_B_layer, neuron_B_id)
    {sensors, neurons} =
      case Map.has_key?(sensors, node_A_id) do
        true ->
          sensor_id = node_A_id
          #Disconnect sensor A from neuron B
          {:ok, {sensors, neurons}} = Sensor.disconnect_from_neuron(sensors, neurons, sensor_id, neuron_B_layer, neuron_B_id, node_A_to_B_connection_id)
          #Create a new neuron
          new_neuron_layer = neuron_B_layer/2
          new_neuron_id = get_node_id.()
          activation_function = Enum.random(activation_functions)
          {:ok, neurons} = Neuron.create(neurons, new_neuron_layer, new_neuron_id, activation_function, learning_function)
          #Connect sensor A to new neuron
          sensor_to_new_neuron_weight = get_random_weight()
          {:ok, {sensors, neurons}} = Sensor.connect_to_neuron(sensors, neurons, sensor_id, new_neuron_layer, new_neuron_id, sensor_to_new_neuron_weight)
          #Connect new neuron to neuron B
          new_neuron_to_B_weight = get_random_weight()
          {:ok, neurons} = Neuron.connect_neurons(neurons, new_neuron_layer, new_neuron_id, neuron_B_layer, neuron_B_id, new_neuron_to_B_weight)
          {sensors, neurons}
        false ->
          neuron_A_id = node_A_id
          {:ok, neuron_A_layer} = Neuron.find_neuron_layer(neurons, neuron_A_id)
          #Disconnect neuron A from neuron B
          {:ok, neurons} = Neuron.disconnect_neurons(neurons, neuron_A_layer, neuron_A_id, neuron_B_layer, neuron_B_id, node_A_to_B_connection_id)
          #Create a new neuron
          new_neuron_layer = (neuron_A_layer + neuron_B_layer) / 2
          new_neuron_id = get_node_id.()
          activation_function = Enum.random(activation_functions)
          {:ok, neurons} = Neuron.create(neurons, new_neuron_layer, new_neuron_id, activation_function, learning_function)
          #Connect neuron A to new neuron
          neuron_A_to_new_neuron_weight = get_random_weight()
          {:ok, neurons} = Neuron.connect_neurons(neurons, neuron_A_layer, neuron_A_id, new_neuron_layer, new_neuron_id, neuron_A_to_new_neuron_weight)
          #Connect new neuron to neuron B
          new_neuron_to_B_weight = get_random_weight()
          {:ok, neurons} = Neuron.connect_neurons(neurons, new_neuron_layer, new_neuron_id, neuron_B_layer, neuron_B_id, new_neuron_to_B_weight)
          {sensors, neurons}
      end
    {:ok, {sensors, neurons}}
  end

  defp add_sensor_link(sensors, neurons) do
    {:ok, sensor_id} = Sensor.get_random_sensor(sensors)
    sensor = Map.get(sensors, sensor_id)
    case Enum.count(sensor.outbound_connections) >= sensor.maximum_vector_size do
      true ->
        {:error, "Sensor has equal parts connections as maximum vector size"}
      false ->
        {:ok, {neuron_layer, neuron_id}} = Neuron.get_random_neuron(neurons)
        weight = get_random_weight()
        {:ok, {sensors, neurons}} = Sensor.connect_to_neuron(sensors, neurons, sensor_id, neuron_layer, neuron_id, weight)
        {:ok, {sensors, neurons}}
     end
  end

  defp add_actuator_link(neurons, actuators) do
    {:ok, actuator_id} = Actuator.get_random_actuator(actuators)
    {:ok, {neuron_layer, neuron_id}} = Neuron.get_random_neuron(neurons)
    {:ok, {neurons, actuators}} = Actuator.connect_neuron_to_actuator(neurons, actuators, neuron_layer, neuron_id, actuator_id)
    {:ok, {neurons, actuators}}
  end

  defp add_sensor(sensors, neurons, sync_functions, get_node_id) do
    #Check if there are already the maximum amount of sensors possible
    case Enum.count(sensors) >= Enum.count(sync_functions) do
      true ->
        {:error, "Equal parts sensors to sync functions"}
      false ->
        #Acquire random Neuron
        {:ok, {neuron_layer, neuron_id}} = Neuron.get_random_neuron(neurons)
        #Limit sync functions to sync functions not used
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
        #Create Sensor
        sensor_id = get_node_id.()
        sync_function_id =
          Enum.random(sync_functions_not_used)
        {:ok, sensors} = Sensor.create(sensors, sensor_id, sync_function_id)

        #Connect sensor to neuron
        weight = get_random_weight()
        {:ok, {sensors, neurons}} = Sensor.connect_to_neuron(sensors, neurons, sensor_id, neuron_layer, neuron_id, weight)
        {:ok, {sensors, neurons}}
    end
  end

  defp add_actuator(neurons, actuators, actuator_functions, get_node_id) do
    #Check if maximum amount of actuators is reached
    case Enum.count(actuators) >= Enum.count(actuator_functions) do
      true ->
        {:error, "Mutation did not occur"}
      false ->
        #Acquire random neuron to connect
        {:ok, {neuron_layer, neuron_id}} = Neuron.get_random_neuron(neurons)
        #Acquire available actuator functions
        actuator_functions_used =
          Enum.map(actuators, fn {_actuator_id, actuator} ->
            case actuator.actuator_function do
              {actuator_function_id, _actuator_function} -> actuator_function_id
              actuator_function_id -> actuator_function_id
            end
          end)
        actuator_functions_not_used =
          Enum.map(actuator_functions, fn actuator_function ->
            case actuator_function do
              {actuator_function_id, _actuator_function} -> actuator_function_id
              actuator_function_id ->
                actuator_function_id
            end
          end)
          |> (fn actuator_function_ids -> actuator_function_ids -- actuator_functions_used end).()
        #Create Actuator
        actuator_function_id =
          Enum.random(actuator_functions_not_used)
        actuator_id = get_node_id.()
        {:ok, actuators} = Actuator.create(actuators, actuator_id, actuator_function_id)
        #Connect Neuron to Actuator
        {:ok, {neurons, actuators}} = Actuator.connect_neuron_to_actuator(neurons, actuators, neuron_layer, neuron_id, actuator_id)
        {:ok, {neurons, actuators}}
    end
  end

  def mutate(%MutationProperties{
        mutation: :add_bias,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators
             }) do
      case add_bias(neurons) do
        {:error, reason} -> {:error, reason}
        {:ok, neurons} -> {:ok, {sensors, neurons, actuators}}
      end
  end

  def mutate(%MutationProperties{
        mutation: :mutate_activation_function,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators,
        activation_functions: activation_functions
             }) do
      case mutate_activation_function(neurons, activation_functions) do
        {:error, reason} -> {:error, reason}
        {:ok, neurons} -> {:ok, {sensors, neurons, actuators}}
      end
  end

  def mutate(%MutationProperties{
        mutation: :remove_bias,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators
             }) do
      case remove_bias(neurons) do
        {:error, reason} -> {:error, reason}
        {:ok, neurons} -> {:ok, {sensors, neurons, actuators}}
      end
  end

  def mutate(%MutationProperties{
        mutation: :mutate_weights,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators
             }) do
      case mutate_weights(neurons) do
        {:error, reason} -> {:error, reason}
        {:ok, neurons} -> {:ok, {sensors, neurons, actuators}}
      end
  end

  def mutate(%MutationProperties{
        mutation: :reset_weights,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators
             }) do
      case reset_weights(neurons) do
        {:error, reason} -> {:error, reason}
        {:ok, neurons} -> {:ok, {sensors, neurons, actuators}}
      end
  end

  def mutate(%MutationProperties{
        mutation: :add_inbound_connection,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators
             }) do
      case add_inbound_connection(neurons) do
        {:error, reason} -> {:error, reason}
        {:ok, neurons} -> {:ok, {sensors, neurons, actuators}}
      end
  end

  def mutate(%MutationProperties{
        mutation: :add_outbound_connection,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators
             }) do
      case add_inbound_connection(neurons) do
        {:error, reason} -> {:error, reason}
        {:ok, neurons} -> {:ok, {sensors, neurons, actuators}}
      end
  end

  def mutate(%MutationProperties{
        mutation: :add_neuron,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators,
        activation_functions: activation_functions,
        learning_function: learning_function,
        get_node_id: get_node_id
             }) do
      case add_neuron(neurons, get_node_id, activation_functions, learning_function) do
        {:error, reason} -> {:error, reason}
        {:ok, neurons} -> {:ok, {sensors, neurons, actuators}}
      end
  end

  def mutate(%MutationProperties{
        mutation: :add_neuron_outsplice,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators,
        activation_functions: activation_functions,
        learning_function: learning_function,
        get_node_id: get_node_id
             }) do
     case add_neuron_outsplice(neurons, actuators, get_node_id, activation_functions, learning_function) do
       {:error, reason} -> {:error, reason}
       {:ok, {neurons, actuators}} -> {:ok, {sensors, neurons, actuators}}
     end
  end

  def mutate(%MutationProperties{
        mutation: :add_neuron_insplice,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators,
        activation_functions: activation_functions,
        learning_function: learning_function,
        get_node_id: get_node_id
             }) do
      case add_neuron_insplice(neurons, sensors, activation_functions, learning_function, get_node_id) do
        {:error, reason} -> {:error, reason}
        {:ok, {sensors, neurons}} -> {:ok, {sensors, neurons, actuators}}
      end
  end

  def mutate(%MutationProperties{
        mutation: :add_sensor_link,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators,
             }) do
      case add_sensor_link(sensors, neurons) do
        {:error, reason} -> {:error, reason}
        {:ok, {sensors, neurons}} -> {:ok, {sensors, neurons, actuators}}
      end
  end

  def mutate(%MutationProperties{
        mutation: :add_actuator_link,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators
             }) do
     case add_actuator_link(neurons, actuators) do
       {:error, reason} -> {:error, reason}
       {:ok, {neurons, actuators}} -> {:ok, {sensors, neurons, actuators}}
     end
  end

  def mutate(%MutationProperties{
        mutation: :add_sensor,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators,
        sync_functions: sync_functions,
        get_node_id: get_node_id
             }) do
    case add_sensor(sensors, neurons, sync_functions, get_node_id) do
      {:error, reason} -> {:error, reason}
      {:ok, {sensors, neurons}} -> {:ok, {sensors, neurons, actuators}}
    end
  end

  def mutate(%MutationProperties{
        mutation: :add_actuator,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators,
        actuator_functions: actuator_functions,
        get_node_id: get_node_id
             }) do
      case add_actuator(neurons, actuators, actuator_functions, get_node_id) do
        {:error, reason} -> {:error, reason}
        {:ok, {neurons, actuators}} -> {:ok, {sensors, neurons, actuators}}
      end
  end

  defp get_mutation_sequence(possible_mutations, number_of_nodes) do
    select_random_mutation =
    fn _junk ->
      Enum.random(possible_mutations)
    end

    number_of_mutations =
      :random.uniform() * :math.sqrt(number_of_nodes)
      |> round

    [0..number_of_mutations]
    |> (fn mutation_list ->
      Enum.map(mutation_list, select_random_mutation)
    end).()
  end

  defp process_mutation_sequence(_mutation_properties, [], {sensors, neurons, actuators}) do
    {sensors, neurons, actuators}
  end

  defp process_mutation_sequence(mutation_properties, [mutation | remaining_mutations], {sensors, neurons, actuators}) do
    mutation_properties = %MutationProperties{mutation_properties |
                                              sensors: sensors,
                                              neurons: neurons,
                                              actuators: actuators,
                                              mutation: mutation
                                             }
    case mutate(mutation_properties) do
      {:error, reason} ->
        Logger.debug fn -> reason end
        process_mutation_sequence(mutation_properties, remaining_mutations, {sensors, neurons, actuators})
      {:ok, {sensors, neurons, actuators}} ->
        process_mutation_sequence(mutation_properties, remaining_mutations, {sensors, neurons, actuators})
    end
  end

  defp process_mutation_sequence(mutation_properties, mutation_sequence) do
    process_mutation_sequence(mutation_properties, mutation_sequence, {mutation_properties.sensors, mutation_properties.neurons, mutation_properties.actuators})
  end

  def mutate_neural_network(possible_mutations, mutation_properties) do
    highest_sensor_id =
      Map.keys(mutation_properties.sensors)
      |> Enum.max
    highest_actuator_id =
      Map.keys(mutation_properties.actuators)
      |> Enum.max
    highest_neuron_id =
      Neuron.get_highest_neuron_id(mutation_properties.neurons)
    highest_node_id =
      [highest_sensor_id, highest_neuron_id, highest_actuator_id]
      |> Enum.max
    {:ok, node_id_generation_pid} = NodeIdGenerator.start_link(highest_node_id)
    get_node_id =
    fn ->
      NodeIdGenerator.get_node_id(node_id_generation_pid)
    end
    mutation_properties = %MutationProperties{mutation_properties |
                                              get_node_id: get_node_id
                                             }
    number_of_neurons =
      Neuron.count_total_neurons(mutation_properties.neurons)

    number_of_nodes =
      number_of_neurons + Enum.count(mutation_properties.sensors) + Enum.count(mutation_properties.actuators)

    mutation_sequence =
      get_mutation_sequence(possible_mutations, number_of_nodes)

    mutated_neural_network =
      process_mutation_sequence(mutation_properties, mutation_sequence)

    GenServer.stop(node_id_generation_pid)

    {:ok, mutated_neural_network}
  end

end
