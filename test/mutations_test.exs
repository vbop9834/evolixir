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

    {mutated_sensors, mutated_neurons, mutated_actuators} = Mutations.mutate(mutation_properties)

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

    {mutated_sensors, mutated_neurons, mutated_actuators} = Mutations.mutate(mutation_properties)

    assert mutated_sensors == mutation_properties.sensors
    assert mutated_actuators == mutation_properties.actuators
    assert Enum.count(mutated_neurons) == 1

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)
    assert mutated_neuron_struct.bias != neuron.bias
    assert mutated_neuron_struct.bias >= 0.0
    assert mutated_neuron_struct.bias <= 1.0
  end

  test ":add_bias should not change the bias of a random neuron if that neuron has a bias and should return a mutation_did_not_occur" do
    neuron_layer = 3
    neuron_id = 8
    neuron = %Neuron{
      neuron_id: neuron_id,
      bias: 3.5
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

    mutation_result = Mutations.mutate(mutation_properties)

    assert mutation_result == :mutation_did_not_occur
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

    {mutated_sensors, mutated_neurons, mutated_actuators} = Mutations.mutate(mutation_properties)

    assert mutated_sensors == mutation_properties.sensors
    assert mutated_actuators == mutation_properties.actuators
    assert Enum.count(mutated_neurons) == 1

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)
    assert mutated_neuron_struct.bias == nil
  end

  test ":remove_bias should return a mutation_did_not_occur if a random neuron already doesn't have a bias" do
    neuron_layer = 3
    neuron_id = 7
    neuron = %Neuron{
      neuron_id: neuron_id,
      bias: nil
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

    mutation_result = Mutations.mutate(mutation_properties)

    assert mutation_result == :mutation_did_not_occur
  end

  test ":mutate_weights should randomly mutate weights from a random inbound connection" do
    fake_from_node_id = :node
    old_weight = 8.0
    neuron_layer = 2
    neuron_id = 9
    {inbound_connections, inbound_connection_id} =
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

    {mutated_sensors, mutated_neurons, mutated_actuators} = Mutations.mutate(mutation_properties)

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
    {inbound_connections, inbound_connection_id} =
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

    {mutated_sensors, mutated_neurons, mutated_actuators} = Mutations.mutate(mutation_properties)

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

    {mutated_sensors, mutated_neurons, mutated_actuators} = Mutations.mutate(mutation_properties)

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

    {mutated_sensors, mutated_neurons, mutated_actuators} = Mutations.mutate(mutation_properties)

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
    mutation_properties = %MutationProperties{
      neurons: neurons,
      mutation: mutation,
      activation_functions: activation_functions
    }

    {mutated_sensors, mutated_neurons, mutated_actuators} = Mutations.mutate(mutation_properties)
    assert mutated_sensors == mutation_properties.sensors
    assert mutated_actuators == mutation_properties.actuators
    assert Enum.count(mutated_neurons) == 1

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    assert Enum.count(mutated_neuron_structs) == 2
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)
    assert mutated_neuron_struct != nil

    assert Enum.count(mutated_neuron_struct.inbound_connections) == 1
    assert Enum.count(mutated_neuron_struct.outbound_connections) == 1

    new_neuron_id = neuron_id + 1
    new_neuron_struct = Map.get(mutated_neuron_structs, new_neuron_id)
    assert new_neuron_struct != nil

    assert Enum.count(new_neuron_struct.inbound_connections) == 1
    assert Enum.count(new_neuron_struct.outbound_connections) == 1
    assert new_neuron_struct.bias == nil
    activation_function = Map.get(activation_functions, activation_function_id)
    assert new_neuron_struct.activation_function == {activation_function_id, activation_function}
  end

  test ":add_neuron_outsplice should disconnect a neuron A to node B then reconnect the nodes with a new neuron as a bridge" do
    fake_actuator_id = 2
    neuron_id = 9
    neuron_layer = 5
    {inbound_connections, connection_id} =
      NeuralNode.add_inbound_connection(neuron_id, 0.0)
    outbound_connections =
      Neuron.add_outbound_connection(fake_actuator_id, connection_id)
    neuron = %Neuron{
      neuron_id: neuron_id,
      outbound_connections: outbound_connections
    }

    neurons = %{
      neuron_layer => %{
        neuron_id => neuron
      }
    }

    actuator = %Actuator{
      actuator_id: fake_actuator_id,
      inbound_connections: inbound_connections
    }
    actuators = %{
      fake_actuator_id => actuator
    }

    mutation = :add_neuron_outsplice
    activation_function_id = :first
    activation_functions = %{
      activation_function_id => :activation_function
    }
    mutation_properties = %MutationProperties{
      neurons: neurons,
      actuators: actuators,
      mutation: mutation,
      activation_functions: activation_functions
    }

    {mutated_sensors, mutated_neurons, mutated_actuators} = Mutations.mutate(mutation_properties)
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

    new_neuron_id = neuron_id + 1
    new_layer_number = neuron_layer + 1
    new_layer = Map.get(mutated_neurons, new_layer_number)
    new_neuron_struct = Map.get(new_layer, new_neuron_id)
    assert new_neuron_struct != nil

    assert Enum.count(new_neuron_struct.inbound_connections) == 1
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

    {sensor, neuron} =
      Sensor.connect_to_neuron(sensor, neuron, 0.0)

    neurons = %{
      neuron_layer => %{
        neuron_id => neuron
      }
    }

    sensors = %{
      sensor_id => sensor
    }

    mutation = :add_neuron_insplice
    activation_function_id = :first
    activation_functions = %{
      activation_function_id => :activation_function
    }
    mutation_properties = %MutationProperties{
      neurons: neurons,
      sensors: sensors,
      mutation: mutation,
      activation_functions: activation_functions
    }

    {mutated_sensors, mutated_neurons, mutated_actuators} = Mutations.mutate(mutation_properties)
    assert mutated_actuators == mutation_properties.actuators
    assert Enum.count(mutated_sensors) == 1
    assert mutated_sensors != mutation_properties.sensors
    assert Enum.count(mutated_neurons) == 2

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    assert Enum.count(mutated_neuron_structs) == 1
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)
    assert mutated_neuron_struct != nil

    assert Enum.count(mutated_neuron_struct.inbound_connections) == 1
    assert Enum.count(mutated_neuron_struct.outbound_connections) == 0

    new_neuron_id = neuron_id + 1
    new_layer_number = neuron_layer/2
    new_layer = Map.get(mutated_neurons, new_layer_number)
    new_neuron_struct = Map.get(new_layer, new_neuron_id)
    assert new_neuron_struct != nil

    assert Enum.count(new_neuron_struct.inbound_connections) == 1
    assert Enum.count(new_neuron_struct.outbound_connections) == 1
    assert Map.has_key?(new_neuron_struct.inbound_connections, sensor_id) == true
    assert new_neuron_struct.bias == nil
    activation_function = Map.get(activation_functions, activation_function_id)
    assert new_neuron_struct.activation_function == {activation_function_id, activation_function}

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

    {mutated_sensors, mutated_neurons, mutated_actuators} = Mutations.mutate(mutation_properties)
    assert mutated_actuators == mutation_properties.actuators
    assert Enum.count(mutated_sensors) == 1
    assert mutated_sensors != mutation_properties.sensors
    assert Enum.count(mutated_neurons) == 1

    mutated_sensor = Map.get(mutated_sensors, sensor_id)
    assert mutated_sensor != sensor
    assert Enum.count(mutated_sensor.outbound_connections) == 1

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    assert Enum.count(mutated_neuron_structs) == 1
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)
    assert mutated_neuron_struct != nil

    assert Enum.count(mutated_neuron_struct.inbound_connections) == 1
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

    mutation_result = Mutations.mutate(mutation_properties)
    assert mutation_result == :mutation_did_not_occur

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

    {mutated_sensors, mutated_neurons, mutated_actuators} = Mutations.mutate(mutation_properties)
    assert Enum.count(mutated_actuators) == 1
    assert mutated_actuators != mutation_properties.actuators
    assert mutated_sensors == mutation_properties.sensors
    assert Enum.count(mutated_neurons) == 1

    mutated_actuator = Map.get(mutated_actuators, actuator_id)
    assert mutated_actuator != actuator
    assert Enum.count(mutated_actuator.inbound_connections) == 1

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    assert Enum.count(mutated_neuron_structs) == 1
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)
    assert mutated_neuron_struct != nil

    assert Enum.count(mutated_neuron_struct.inbound_connections) == 0
    assert Enum.count(mutated_neuron_struct.outbound_connections) == 1

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
    mutation = :add_sensor
    mutation_properties = %MutationProperties{
      neurons: neurons,
      sensors: sensors,
      sync_functions: sync_functions,
      mutation: mutation
    }

    {mutated_sensors, mutated_neurons, mutated_actuators} = Mutations.mutate(mutation_properties)
    assert mutated_actuators == mutation_properties.actuators
    assert Enum.count(mutated_sensors) == 2
    assert mutated_sensors != mutation_properties.sensors
    assert Enum.count(mutated_neurons) == 1

    new_sensor_id = fake_sensor_id + 1
    mutated_sensor = Map.get(mutated_sensors, new_sensor_id)
    assert Enum.count(mutated_sensor.outbound_connections) == 1
    assert mutated_sensor.sync_function == sync_function_id
    assert mutated_sensor.sensor_id == new_sensor_id

    mutated_neuron_structs = Map.get(mutated_neurons, neuron_layer)
    assert Enum.count(mutated_neuron_structs) == 1
    mutated_neuron_struct = Map.get(mutated_neuron_structs, neuron_id)
    assert mutated_neuron_struct != nil

    assert Enum.count(mutated_neuron_struct.inbound_connections) == 1
    assert Enum.count(mutated_neuron_struct.outbound_connections) == 0

  end

end
