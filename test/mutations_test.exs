defmodule Evolixir.MutationsTest do
  use ExUnit.Case
  doctest Mutations

  test "the mutation :mutate_activation_function should randomly select an activation function" do
    neuron_layer = 1
    neuron_id = 5
    activation_function_with_id = {:first, 1}
    neuron = %Neuron{
      neuron_id: neuron_id,
      activation_function: activation_function_with_id
    }
    neurons = %{
      neuron_layer => %{
        neuron.neuron_id => neuron
      }
    }

    desired_activation_function_id = :second
    desired_activation_function = 2
    mutation = :mutate_activation_function
    mutation_properties = %MutationProperties{
      neurons: neurons,
      mutation: mutation,
      activation_functions: %{ desired_activation_function_id => desired_activation_function }
    }

    {:ok, {mutated_sensors, mutated_neurons, mutated_actuators}} = Mutations.mutate(mutation_properties)

    assert mutated_sensors == mutation_properties.sensors
    assert mutated_actuators == mutation_properties.actuators
    assert Enum.count(mutated_neurons) == 1

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)

    {mutated_activation_function_id, mutated_activation_function} = mutated_neuron_struct.activation_function

    assert mutated_activation_function_id == desired_activation_function_id
    assert mutated_activation_function == desired_activation_function
  end

  test ":add_bias should add a bias to a random neuron if that neuron has no bias" do
    neuron_layer = 3
    neuron_id = 8
    neuron = %Neuron{
      neuron_id: neuron_id,
      bias: nil
    }
    neurons = %{
      neuron_layer => %{
        neuron.neuron_id => neuron
      }
    }

    mutation = :add_bias
    mutation_properties = %MutationProperties{
      neurons: neurons,
      mutation: mutation
    }

    {:ok,{mutated_sensors, mutated_neurons, mutated_actuators}} = Mutations.mutate(mutation_properties)

    assert mutated_sensors == mutation_properties.sensors
    assert mutated_actuators == mutation_properties.actuators
    assert Enum.count(mutated_neurons) == 1

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)
    assert mutated_neuron_struct.bias != neuron.bias
    assert mutated_neuron_struct.bias >= 0.0
    assert mutated_neuron_struct.bias <= 1.0
  end

  test ":remove_bias should remove a bias from a random neuron if that neuron has a bias" do
    neuron_layer = 2
    neuron_id = 9
    neuron = %Neuron{
      neuron_id: neuron_id,
      bias: 2.0
    }
    neurons = %{
      neuron_layer => %{
    neuron.neuron_id => neuron
  }
    }

    mutation = :remove_bias
    mutation_properties = %MutationProperties{
      neurons: neurons,
      mutation: mutation
    }

    {:ok,{mutated_sensors, mutated_neurons, mutated_actuators}} = Mutations.mutate(mutation_properties)

    assert mutated_sensors == mutation_properties.sensors
    assert mutated_actuators == mutation_properties.actuators
    assert Enum.count(mutated_neurons) == 1

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)
    assert mutated_neuron_struct.bias == nil
  end

  test ":mutate_weights should randomly mutate weights from a random inbound connection" do
    fake_from_node_id = :node
    old_weight = 10000.0
    neuron_layer = 2
    neuron_id = 9
    {:ok, {inbound_connections, inbound_connection_id}} =
      NeuralNode.add_inbound_connection(fake_from_node_id, old_weight)
    neuron = %Neuron{
      neuron_id: neuron_id,
      bias: 2.0,
      inbound_connections: inbound_connections
    }
    neurons = %{
      neuron_layer => %{
        neuron.neuron_id => neuron
      }
    }

    mutation = :mutate_weights
    mutation_properties = %MutationProperties{
      neurons: neurons,
      mutation: mutation
    }

    {:ok,{mutated_sensors, mutated_neurons, mutated_actuators}} = Mutations.mutate(mutation_properties)

    assert mutated_sensors == mutation_properties.sensors
    assert mutated_actuators == mutation_properties.actuators
    assert Enum.count(mutated_neurons) == 1

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)

    assert Enum.count(mutated_neuron_struct.inbound_connections) == 1

    mutated_inbound_connections_from_node = Map.get(mutated_neuron_struct.inbound_connections, fake_from_node_id)
    assert Enum.count(mutated_inbound_connections_from_node) == 1
    mutated_inbound_connection_weight = Map.get(mutated_inbound_connections_from_node, inbound_connection_id)
    assert mutated_inbound_connection_weight < old_weight
  end

  test ":reset_weights should reset weights from a random node" do
    fake_from_node_id = :node
    old_weight = 8.0
    neuron_layer = 2
    neuron_id = 9
    {:ok, {inbound_connections, inbound_connection_id}} =
      NeuralNode.add_inbound_connection(fake_from_node_id, old_weight)
    neuron = %Neuron{
      neuron_id: neuron_id,
      bias: 2.0,
      inbound_connections: inbound_connections
    }
    neurons = %{
      neuron_layer => %{
        neuron.neuron_id => neuron
      }
    }

    mutation = :reset_weights
    mutation_properties = %MutationProperties{
      neurons: neurons,
      mutation: mutation
    }

    {:ok, {mutated_sensors, mutated_neurons, mutated_actuators}} = Mutations.mutate(mutation_properties)

    assert mutated_sensors == mutation_properties.sensors
    assert mutated_actuators == mutation_properties.actuators
    assert Enum.count(mutated_neurons) == 1

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)

    assert Enum.count(mutated_neuron_struct.inbound_connections) == 1

    mutated_inbound_connections_from_node = Map.get(mutated_neuron_struct.inbound_connections, fake_from_node_id)
    assert Enum.count(mutated_inbound_connections_from_node) == 1
    mutated_inbound_connection_weight = Map.get(mutated_inbound_connections_from_node, inbound_connection_id)
    assert mutated_inbound_connection_weight < old_weight
  end

  test ":add_inbound_connection should add a random inbound connection" do
    neuron_id = 9
    neuron_layer = 1
    neuron = %Neuron{
      neuron_id: neuron_id
    }

    neurons = %{
      neuron_layer => %{
        neuron.neuron_id => neuron
      }
    }

    mutation = :add_inbound_connection
    mutation_properties = %MutationProperties{
      neurons: neurons,
      mutation: mutation
    }

    {:ok,{mutated_sensors, mutated_neurons, mutated_actuators}} = Mutations.mutate(mutation_properties)

    assert mutated_sensors == mutation_properties.sensors
    assert mutated_actuators == mutation_properties.actuators
    assert Enum.count(mutated_neurons) == 1

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)

    assert Enum.count(mutated_neuron_struct.inbound_connections) == 1
    assert Enum.count(mutated_neuron_struct.outbound_connections) == 1

   mutated_outbound_connections = Map.keys(mutated_neuron_struct.outbound_connections)
   {outbound_neuron_id, mutated_connection_id} =
     hd mutated_outbound_connections
   assert outbound_neuron_id == neuron_id

   mutated_inbound_connections_from_node = Map.get(mutated_neuron_struct.inbound_connections, neuron_id)
   assert Enum.count(mutated_inbound_connections_from_node) == 1
   mutated_weight = Map.get(mutated_inbound_connections_from_node, mutated_connection_id)
   min_weight_possible = -1.0 * (:math.pi / 2.0)
   max_weight_possible = :math.pi / 2.0
   assert mutated_weight > min_weight_possible
   assert mutated_weight <= max_weight_possible
  end

  test ":add_outbound_connection should add a random outbound connection" do
    neuron_id = 9
    neuron_layer = 1
    neuron = %Neuron{
      neuron_id: neuron_id
    }

    neurons = %{
      neuron_layer => %{
        neuron.neuron_id => neuron
      }
    }

    mutation = :add_outbound_connection
    mutation_properties = %MutationProperties{
      neurons: neurons,
      mutation: mutation
    }

    {:ok, {mutated_sensors, mutated_neurons, mutated_actuators}} = Mutations.mutate(mutation_properties)

    assert mutated_sensors == mutation_properties.sensors
    assert mutated_actuators == mutation_properties.actuators
    assert Enum.count(mutated_neurons) == 1

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)

    assert Map.has_key?(mutated_neuron_struct.outbound_connections, {neuron_id, 1})

    assert Enum.count(mutated_neuron_struct.inbound_connections) == 1
    mutated_inbound_connections_from_node = Map.get(mutated_neuron_struct.inbound_connections, neuron_id)
    assert Enum.count(mutated_inbound_connections_from_node) == 1
    mutated_weight = Map.get(mutated_inbound_connections_from_node, 1)
    min_weight_possible = -1.0 * (:math.pi / 2.0)
    max_weight_possible = :math.pi / 2.0
    assert mutated_weight > min_weight_possible
    assert mutated_weight <= max_weight_possible
  end

  test ":add_neuron should add a neuron in a known layer, connecting it from and to two random neurons" do
    neuron_id = 4
    neuron_layer = 98
    neuron = %Neuron{
      neuron_id: neuron_id
    }

    neurons = %{
      neuron_layer => %{
        neuron.neuron_id => neuron
      }
    }

    mutation = :add_neuron
    activation_function_id = :first
    activation_functions = %{
      activation_function_id => :activation_function
    }
    new_neuron_id = neuron_id + 1
    get_node_id = fn -> new_neuron_id end
    mutation_properties = %MutationProperties{
      neurons: neurons,
      mutation: mutation,
      activation_functions: activation_functions,
      get_node_id: get_node_id
    }

    {:ok,{mutated_sensors, mutated_neurons, mutated_actuators}} = Mutations.mutate(mutation_properties)
    assert mutated_sensors == mutation_properties.sensors
    assert mutated_actuators == mutation_properties.actuators
    assert Enum.count(mutated_neurons) == 1

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    assert Enum.count(mutated_neuron_structs) == 2
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)
    assert mutated_neuron_struct != nil

    assert Enum.count(mutated_neuron_struct.inbound_connections) == 1
    assert Enum.count(mutated_neuron_struct.outbound_connections) == 1

    new_neuron_struct = Map.get(mutated_neuron_structs, new_neuron_id)
    assert new_neuron_struct != nil

    assert Enum.count(new_neuron_struct.inbound_connections) == 1
    {from_node_id, inbound_connections_from_node} = Enum.to_list(new_neuron_struct.inbound_connections) |> hd
    assert from_node_id != nil
    assert Enum.count(inbound_connections_from_node) == 1
    new_weight = Enum.to_list(inbound_connections_from_node) |> hd
    assert new_weight != nil
    assert Enum.count(new_neuron_struct.outbound_connections) == 1
    assert new_neuron_struct.bias == nil
    activation_function = Map.get(activation_functions, activation_function_id)
    assert new_neuron_struct.activation_function == {activation_function_id, activation_function}
  end

  test ":add_neuron_outsplice should disconnect a neuron A to node B then reconnect the nodes with a new neuron as a bridge" do
    fake_actuator_id = 2
    neuron_id = 9
    neuron_layer = 5
    neuron = %Neuron{
      neuron_id: neuron_id
    }

    neurons = %{
      neuron_layer => %{
        neuron_id => neuron
      }
    }

    actuator = %Actuator{
      actuator_id: fake_actuator_id
    }
    actuators = %{
      fake_actuator_id => actuator
    }
    {:ok, {neurons, actuators}} = Actuator.connect_neuron_to_actuator(neurons, actuators, neuron_layer, neuron_id, fake_actuator_id)

    mutation = :add_neuron_outsplice
    activation_function_id = :first
    activation_functions = %{
      activation_function_id => :activation_function
    }
    new_neuron_id = neuron_id + 1
    get_node_id = fn -> new_neuron_id end
    mutation_properties = %MutationProperties{
      neurons: neurons,
      actuators: actuators,
      mutation: mutation,
      activation_functions: activation_functions,
      get_node_id: get_node_id
    }

    {:ok,{mutated_sensors, mutated_neurons, mutated_actuators}} = Mutations.mutate(mutation_properties)
    assert mutated_sensors == mutation_properties.sensors
    assert Enum.count(mutated_actuators) == 1
    assert mutated_actuators != mutation_properties.actuators
    assert Enum.count(mutated_neurons) == 2

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    assert Enum.count(mutated_neuron_structs) == 1
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)
    assert mutated_neuron_struct != nil

    assert Enum.count(mutated_neuron_struct.inbound_connections) == 0
    assert Enum.count(mutated_neuron_struct.outbound_connections) == 1
    assert Map.has_key?(mutated_neuron_struct.outbound_connections, {new_neuron_id, 1})

    new_layer_number = neuron_layer + 1
    new_layer = Map.get(mutated_neurons, new_layer_number)
    new_neuron_struct = Map.get(new_layer, new_neuron_id)
    assert new_neuron_struct != nil

    assert Enum.count(new_neuron_struct.inbound_connections) == 1
    connections_from_neuron = Map.get(new_neuron_struct.inbound_connections, neuron_id)
    assert Enum.count(connections_from_neuron) == 1
    connection_id = 1
    new_weight = Map.get(connections_from_neuron, connection_id)
    assert new_weight != nil
    assert Enum.count(new_neuron_struct.outbound_connections) == 1
    assert Map.has_key?(new_neuron_struct.outbound_connections, {fake_actuator_id, 1}) == true
    assert new_neuron_struct.bias == nil
    activation_function = Map.get(activation_functions, activation_function_id)
    assert new_neuron_struct.activation_function == {activation_function_id, activation_function}

  end

  test ":add_neuron_insplice should disconnect node B to neuron A then reconnect the nodes with a new neuron as a bridge" do
    sensor_id = 3
    neuron_id = 9
    neuron_layer = 5
    neuron = %Neuron{
      neuron_id: neuron_id
    }
    sensor = %Sensor{
      sensor_id: sensor_id
    }

    neurons = %{
      neuron_layer => %{
        neuron_id => neuron
      }
    }

    sensors = %{
      sensor_id => sensor
    }

    {:ok, {sensors, neurons}} = Sensor.connect_to_neuron(sensors, neurons, sensor_id, neuron_layer, neuron_id, 0.0)

    mutation = :add_neuron_insplice
    activation_function_id = :first
    activation_functions = %{
      activation_function_id => :activation_function
    }
    new_neuron_id = neuron_id + 1
    get_node_id = fn -> new_neuron_id end
    mutation_properties = %MutationProperties{
      neurons: neurons,
      sensors: sensors,
      mutation: mutation,
      activation_functions: activation_functions,
      get_node_id: get_node_id
    }

    {:ok,{mutated_sensors, mutated_neurons, mutated_actuators}} = Mutations.mutate(mutation_properties)
    assert mutated_actuators == mutation_properties.actuators
    assert Enum.count(mutated_sensors) == 1
    assert mutated_sensors != mutation_properties.sensors
    assert Enum.count(mutated_neurons) == 2

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    assert Enum.count(mutated_neuron_structs) == 1
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)
    assert mutated_neuron_struct != nil

    assert Enum.count(mutated_neuron_struct.inbound_connections) == 1
    connections_from_new_neuron = Map.get(mutated_neuron_struct.inbound_connections, new_neuron_id)
    assert Enum.count(connections_from_new_neuron) == 1
    new_weight = Map.get(connections_from_new_neuron, 1)
    assert new_weight != nil
    assert Enum.count(mutated_neuron_struct.outbound_connections) == 0

    new_layer_number = neuron_layer/2
    new_layer = Map.get(mutated_neurons, new_layer_number)
    new_neuron_struct = Map.get(new_layer, new_neuron_id)
    assert new_neuron_struct != nil

    assert Enum.count(new_neuron_struct.inbound_connections) == 1
    connections_from_sensor = Map.get(new_neuron_struct.inbound_connections, sensor_id)
    assert Enum.count(connections_from_sensor) == 1
    new_weight = Map.get(connections_from_sensor, 1)
    assert new_weight != nil
    assert Enum.count(new_neuron_struct.outbound_connections) == 1
    assert new_neuron_struct.bias == nil
    activation_function = Map.get(activation_functions, activation_function_id)
    assert new_neuron_struct.activation_function == {activation_function_id, activation_function}

    mutated_sensor = Map.get(mutated_sensors, sensor_id)
    assert Enum.count(mutated_sensor.outbound_connections) == 1
    {to_node_id, connection_id} = hd mutated_sensor.outbound_connections
    assert to_node_id == new_neuron_id
    assert connection_id == 1
  end

  test ":add_sensor_link should connect a random sensor to a random neuron" do
    sensor_id = 3
    neuron_id = 9
    neuron_layer = 5
    neuron = %Neuron{
      neuron_id: neuron_id
    }
    sensor = %Sensor{
      maximum_vector_size: 5,
      sensor_id: sensor_id
    }

    neurons = %{
      neuron_layer => %{
        neuron_id => neuron
      }
    }

    sensors = %{
      sensor_id => sensor
    }

    mutation = :add_sensor_link
    mutation_properties = %MutationProperties{
      neurons: neurons,
      sensors: sensors,
      mutation: mutation
    }

    {:ok,{mutated_sensors, mutated_neurons, mutated_actuators}} = Mutations.mutate(mutation_properties)
    assert mutated_actuators == mutation_properties.actuators
    assert Enum.count(mutated_sensors) == 1
    assert mutated_sensors != mutation_properties.sensors
    assert Enum.count(mutated_neurons) == 1

    mutated_sensor = Map.get(mutated_sensors, sensor_id)
    assert mutated_sensor != sensor
    assert Enum.count(mutated_sensor.outbound_connections) == 1
    {to_node_id, connection_id} = hd mutated_sensor.outbound_connections
    assert to_node_id == neuron_id
    assert connection_id == 1

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    assert Enum.count(mutated_neuron_structs) == 1
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)
    assert mutated_neuron_struct != nil

    assert Enum.count(mutated_neuron_struct.inbound_connections) == 1
    connections_from_sensor = Map.get(mutated_neuron_struct.inbound_connections, sensor_id)
    assert Enum.count(connections_from_sensor) == 1
    new_weight = Map.get(connections_from_sensor, 1)
    assert new_weight != nil
    assert Enum.count(mutated_neuron_struct.outbound_connections) == 0
  end

  test ":add_sensor_link should not connect a sensor to a random neuron if the sensor had more outbound connections than maximum_vector_size" do
    sensor_id = 3
    neuron_id = 9
    neuron_layer = 5
    neuron = %Neuron{
      neuron_id: neuron_id
    }
    sensor = %Sensor{
      maximum_vector_size: 0,
      sensor_id: sensor_id
    }

    neurons = %{
      neuron_layer => %{
        neuron_id => neuron
      }
    }

    sensors = %{
      sensor_id => sensor
    }

    mutation = :add_sensor_link
    mutation_properties = %MutationProperties{
      neurons: neurons,
      sensors: sensors,
      mutation: mutation
    }

    {mutation_result, _reason} = Mutations.mutate(mutation_properties)
    assert mutation_result == :error

  end

  test ":add_actuator_link should connect a random neuron to a random actuator" do
    actuator_id = 7
    neuron_id = 9
    neuron_layer = 5
    neuron = %Neuron{
      neuron_id: neuron_id
    }
    actuator = %Actuator{
      actuator_id: actuator_id
    }

    neurons = %{
      neuron_layer => %{
        neuron_id => neuron
      }
    }

    actuators = %{
      actuator_id => actuator
    }

    mutation = :add_actuator_link
    mutation_properties = %MutationProperties{
      neurons: neurons,
      actuators: actuators,
      mutation: mutation
    }

    {:ok,{mutated_sensors, mutated_neurons, mutated_actuators}} = Mutations.mutate(mutation_properties)
    assert Enum.count(mutated_actuators) == 1
    assert mutated_actuators != mutation_properties.actuators
    assert mutated_sensors == mutation_properties.sensors
    assert Enum.count(mutated_neurons) == 1

    mutated_actuator = Map.get(mutated_actuators, actuator_id)
    assert mutated_actuator != actuator
    assert Enum.count(mutated_actuator.inbound_connections) == 1
    connections_from_neuron = Map.get(mutated_actuator.inbound_connections, neuron_id)
    assert Enum.count(connections_from_neuron) == 1
    assert Map.has_key?(connections_from_neuron, 1) == true

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    assert Enum.count(mutated_neuron_structs) == 1
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)
    assert mutated_neuron_struct != nil

    assert Enum.count(mutated_neuron_struct.inbound_connections) == 0
    assert Enum.count(mutated_neuron_struct.outbound_connections) == 1
    assert Map.has_key?(mutated_neuron_struct.outbound_connections, {actuator_id, 1})
  end

  test ":add_sensor should add a new sensor if a sync function is available" do
    fake_sensor_id = 4
    used_sync_function = {:used, nil}
    sensor = %Sensor{
      sensor_id: 4,
      sync_function: used_sync_function
    }
    sensors = %{
      fake_sensor_id => sensor
    }
    neuron_id = 9
    neuron_layer = 5
    neuron = %Neuron{
      neuron_id: neuron_id
    }

    neurons = %{
      neuron_layer => %{
        neuron_id => neuron
      }
    }

    sync_function_id = :sync_func
    sync_function = {sync_function_id, nil}
    sync_functions = [sync_function, used_sync_function]
    new_sensor_id = fake_sensor_id + 1
    get_node_id = fn -> new_sensor_id end
    mutation = :add_sensor
    mutation_properties = %MutationProperties{
      neurons: neurons,
      sensors: sensors,
      sync_functions: sync_functions,
      mutation: mutation,
      get_node_id: get_node_id
    }

    {:ok, {mutated_sensors, mutated_neurons, mutated_actuators}} = Mutations.mutate(mutation_properties)
    assert mutated_actuators == mutation_properties.actuators
    assert Enum.count(mutated_sensors) == 2
    assert mutated_sensors != mutation_properties.sensors
    assert Enum.count(mutated_neurons) == 1

    mutated_sensor = Map.get(mutated_sensors, new_sensor_id)
    assert Enum.count(mutated_sensor.outbound_connections) == 1
    {to_neuron_id, connection_id} = hd mutated_sensor.outbound_connections
    assert to_neuron_id == neuron_id
    assert connection_id == 1
    assert mutated_sensor.sync_function == sync_function_id
    assert mutated_sensor.sensor_id == new_sensor_id

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    assert Enum.count(mutated_neuron_structs) == 1
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)
    assert mutated_neuron_struct != nil

    assert Enum.count(mutated_neuron_struct.inbound_connections) == 1
    connections_from_sensor = Map.get(mutated_neuron_struct.inbound_connections, new_sensor_id)
    assert Enum.count(connections_from_sensor) == 1
    new_weight = Map.get(connections_from_sensor, 1)
    assert new_weight != nil
    assert Enum.count(mutated_neuron_struct.outbound_connections) == 0
  end

  test ":add_sensor should not add a new sensor if all sync functions are used" do
    fake_sensor_id = 4
    used_sync_function = {:used, nil}
    sensor = %Sensor{
      sensor_id: 4,
      sync_function: used_sync_function
    }
    sensors = %{
      fake_sensor_id => sensor
    }
    neuron_id = 9
    neuron_layer = 5
    neuron = %Neuron{
      neuron_id: neuron_id
    }

    neurons = %{
      neuron_layer => %{
        neuron_id => neuron
      }
    }

    sync_functions = [used_sync_function]
    mutation = :add_sensor
    mutation_properties = %MutationProperties{
      neurons: neurons,
      sensors: sensors,
      sync_functions: sync_functions,
      mutation: mutation
    }

    {mutation_result, _reason} = Mutations.mutate(mutation_properties)
    assert mutation_result == :error
  end

  test ":add_actuator should add a new actuator if an actuator function is available" do
    fake_actuator_id = 74
    used_actuator_function = {:used, nil}
    actuator = %Actuator{
      actuator_id: 4,
      actuator_function: used_actuator_function
    }
    actuators = %{
      fake_actuator_id => actuator
    }
    neuron_id = 9
    neuron_layer = 5
    neuron = %Neuron{
      neuron_id: neuron_id
    }

    neurons = %{
      neuron_layer => %{
        neuron_id => neuron
      }
    }

    actuator_function_id = :actuator_func
    actuator_function = {actuator_function_id, nil}
    actuator_functions = [actuator_function, used_actuator_function]
    mutation = :add_actuator
    new_actuator_id = fake_actuator_id + 1
    get_node_id = fn -> new_actuator_id end
    mutation_properties = %MutationProperties{
      neurons: neurons,
      actuators: actuators,
      actuator_functions: actuator_functions,
      mutation: mutation,
      get_node_id: get_node_id
    }

    {:ok, {mutated_sensors, mutated_neurons, mutated_actuators}} = Mutations.mutate(mutation_properties)
    assert mutated_actuators != mutation_properties.actuators
    assert Enum.count(mutated_actuators) == 2
    assert mutated_sensors == mutation_properties.sensors
    assert Enum.count(mutated_neurons) == 1

    mutated_actuator = Map.get(mutated_actuators, new_actuator_id)
    assert Enum.count(mutated_actuator.inbound_connections) == 1
    connections_from_neuron = Map.get(mutated_actuator.inbound_connections, neuron_id)
    assert Map.has_key?(connections_from_neuron, 1)
    assert mutated_actuator.actuator_function == actuator_function_id
    assert mutated_actuator.actuator_id == new_actuator_id

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    assert Enum.count(mutated_neuron_structs) == 1
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)
    assert mutated_neuron_struct != nil

    assert Enum.count(mutated_neuron_struct.inbound_connections) == 0
    assert Enum.count(mutated_neuron_struct.outbound_connections) == 1
    assert Map.has_key?(mutated_neuron_struct.outbound_connections, {new_actuator_id, 1})
  end

  test ":add_actuator should not add a new actuator if all actuator functions are used" do
    fake_actuator_id = 74
    used_actuator_function = {:used, nil}
    actuator = %Actuator{
      actuator_id: 4,
      actuator_function: used_actuator_function
    }
    actuators = %{
      fake_actuator_id => actuator
    }
    neuron_id = 9
    neuron_layer = 5
    neuron = %Neuron{
      neuron_id: neuron_id
    }

    neurons = %{
      neuron_layer => %{
        neuron_id => neuron
      }
    }

    actuator_functions = [used_actuator_function]
    mutation = :add_actuator
    mutation_properties = %MutationProperties{
      neurons: neurons,
      actuators: actuators,
      actuator_functions: actuator_functions,
      mutation: mutation
    }

    {mutation_result, _reason} = Mutations.mutate(mutation_properties)
    assert mutation_result == :error
  end

  test "mutate_neural_network should mutate a neural network randomly" do
    sensor_id = 1
    neuron_id = 2
    actuator_id = 3

    used_sync_function_id = :used_sync
    sensor = %Sensor{
      maximum_vector_size: 5,
      sensor_id: sensor_id,
      sync_function: used_sync_function_id
    }

    used_activation_function_id = :used_activation_func
    neuron_layer = 1
    neuron = %Neuron{
      neuron_id: neuron_id,
      activation_function: used_activation_function_id
    }

    used_actuator_function_id = :used_actuator_func
    actuator = %Actuator{
      actuator_id: actuator_id,
      actuator_function: used_actuator_function_id
    }

    sensors = %{
      sensor_id => sensor
    }

    neurons = %{
      neuron_layer => %{
        neuron_id => neuron
      }
    }

    actuators = %{
      actuator_id => actuator
    }

    {:ok,{sensors, neurons}} = Sensor.connect_to_neuron(sensors, neurons, sensor_id, neuron_layer, neuron_id, 0.0)
    {:ok,{neurons, actuators}} = Actuator.connect_neuron_to_actuator(neurons, actuators, neuron_layer, neuron_id, actuator_id)

    sync_function_id = :sync
    sync_function = {sync_function_id, nil}
    sync_functions = [{used_sync_function_id, nil}, sync_function]

    activation_function_id = :activation_func
    activation_function = {activation_function_id, nil}
    activation_functions = [activation_function, {used_activation_function_id, nil}]

    actuator_function_id = :actuator_func
    actuator_function = {actuator_function_id, nil}
    actuator_functions = [actuator_function, {used_actuator_function_id, nil}]

    mutation_properties = %MutationProperties{
      sensors: sensors,
      neurons: neurons,
      actuators: actuators,
      activation_functions: activation_functions,
      actuator_functions: actuator_functions,
      sync_functions: sync_functions
    }

    mutations = Mutations.default_mutation_sequence
    {:ok, {mutated_sensors, mutated_neurons, mutated_actuators}} = Mutations.mutate_neural_network(mutations, mutation_properties)

    assert Enum.count(mutated_sensors) > 0
    assert Enum.count(mutated_neurons) > 0
    assert Enum.count(mutated_actuators) > 0

    test_sensor = fn {sensor_id, sensor} ->
      assert sensor.sensor_id > 0
      assert sensor_id == sensor.sensor_id
      assert Enum.count(sensor.outbound_connections) > 0
      assert sensor.maximum_vector_size != nil
      assert sensor.sync_function != nil
    end
    test_neuron_layer = fn {neuron_layer, neuron_structs} ->
      assert neuron_layer > 0
      test_neuron = fn {neuron_id, neuron} ->
        assert neuron.neuron_id > 0
        assert neuron_id == neuron.neuron_id
        assert Enum.count(neuron.inbound_connections) > 0
        assert Enum.count(neuron.outbound_connections) > 0
      end
      Enum.each(neuron_structs, test_neuron)
    end
    test_actuator = fn {actuator_id, actuator} ->
      assert actuator.actuator_id > 0
      assert actuator_id == actuator.actuator_id
      assert Enum.count(actuator.inbound_connections) > 0
      assert actuator.actuator_function != nil
    end

    Enum.each(mutated_sensors, test_sensor)
    Enum.each(mutated_neurons, test_neuron_layer)
    Enum.each(mutated_actuators, test_actuator)
  end

end
