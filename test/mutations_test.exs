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

end
