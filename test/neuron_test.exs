defmodule Evolixir.NeuronTest do
  use ExUnit.Case
  doctest Neuron

  test "add_outbound_connection should add an outbound connection to a neuron map" do
    neuron_id = 1
    neuron = %Neuron{
      neuron_id: neuron_id
    }
    neuron_layer = 1
    neurons = %{
      neuron_layer => %{neuron_id => neuron}
    }
    to_node_id = 3
    connection_id = 1
    {:ok, neurons} =
      Neuron.add_outbound_connection(neurons, neuron_layer, neuron_id, to_node_id, connection_id)
    {:ok, neuron} = Neuron.get_neuron(neurons, neuron_layer, neuron_id)

    assert neuron.outbound_connections == %{{to_node_id, connection_id} => nil}
  end

  test "sigmoid should work" do
    result = ActivationFunction.sigmoid(1.0)
    assert_in_delta result, 0.731, 0.001
  end

  test "apply_weight_to_syntax should multiply the weight by the synapse value and return an updated weighted synapse" do
    synapse = %Synapse{value: 1.0}
    inbound_connection_weight = 5.0
    weighted_synapse = Neuron.apply_weight_to_synapse(synapse, inbound_connection_weight)
    assert weighted_synapse.value == 5.0
  end

  test "calculate_output_value should calculate output value from full barrier" do
    first_synapse = %Synapse{value: 1.5}
    second_synapse = %Synapse{value: 2.5}
    barrier =
      %{
        1 => first_synapse,
        2 => second_synapse
      }
    activation_function = fn x -> x end
    output_value = Neuron.calculate_output_value(barrier, activation_function, 0.0)

    expected_value = first_synapse.value + second_synapse.value
    assert output_value == expected_value
  end

  test "calculate_output_value should add the bias" do
    first_synapse = %Synapse{value: 1.5}
    second_synapse = %Synapse{value: 2.5}
    barrier =
      %{
        1 => first_synapse,
        2 => second_synapse
      }
    activation_function = fn x -> x end
    bias = 5.0
    output_value = Neuron.calculate_output_value(barrier, activation_function, bias)

    expected_value = first_synapse.value + second_synapse.value + bias
    assert output_value == expected_value
  end

  test "calculate_output_value should work with a nil bias" do
    first_synapse = %Synapse{value: 1.5}
    second_synapse = %Synapse{value: 2.5}
    barrier =
      %{
        1 => first_synapse,
        2 => second_synapse
      }
    activation_function = fn x -> x end
    bias = nil
    output_value = Neuron.calculate_output_value(barrier, activation_function, bias)

    expected_value = first_synapse.value + second_synapse.value
    assert output_value == expected_value
  end

  test "calculate_output_value should calculate output value from full barrier with an activation function" do
    first_synapse = %Synapse{value: 1.5}
    second_synapse = %Synapse{value: 2.5}
    barrier =
      %{
        1 => first_synapse,
        2 => second_synapse
      }
    activation_function = &ActivationFunction.sigmoid/1
    output_value = Neuron.calculate_output_value(barrier, activation_function, 0.0)

    expected_value = (first_synapse.value + second_synapse.value) |> activation_function.()
    assert output_value == expected_value
  end

  test "Upon receiving a synapse, if the updated_barrier is full then the Neuron should send a synapse to its outbound connections" do
    activation_function_with_id = {:sigmoid, &ActivationFunction.sigmoid/1}
    weight = 1.0
    neuron_id = :neuron
    fake_from_node_id = 5
    fake_test_helper_connection_id = 9
    {:ok, {inbound_connections, neuron_inbound_connection_id}} = NeuralNode.add_inbound_connection(fake_from_node_id, weight)
    neuron_test_helper_pid = :test_helper
    {:ok, _} = NodeTestHelper.start_link(neuron_test_helper_pid)
    outbound_connections = Neuron.add_outbound_connection_to_connections(neuron_test_helper_pid, fake_test_helper_connection_id)
    {:ok, _} = GenServer.start_link(Neuron,
      %Neuron{
        neuron_id: neuron_id,
        activation_function: activation_function_with_id,
        inbound_connections: inbound_connections,
        outbound_connections: outbound_connections
      }, name: neuron_id)
    artificial_synapse = %Synapse{
      value: 1.0,
      from_node_id: fake_from_node_id,
      connection_id: neuron_inbound_connection_id
    }
    :ok = GenServer.cast(neuron_id, {:receive_synapse, artificial_synapse})

    #TODO find a better way to wait for the async op
    :timer.sleep(5)
    updated_test_state = GenServer.call(neuron_test_helper_pid, :get_state)
    assert tuple_size(updated_test_state.received_synapses) == 1

    {received_synapse} = updated_test_state.received_synapses
    assert received_synapse.connection_id == fake_test_helper_connection_id
    assert_in_delta received_synapse.value, 0.7310, 0.001
    assert received_synapse.from_node_id == neuron_id
  end

  test "Upon receiving a synapse, if the updated_barrier is not full then the Neuron should not send a synapse to its outbound connections" do
    activation_function_with_id = {:sigmoid, &ActivationFunction.sigmoid/1}
    weight = 1.0
    neuron_id = :neuron
    fake_from_node_id = 5
    fake_test_helper_connection_id = 9
    {:ok, {inbound_connections_count_one, neuron_inbound_connection_id}} = NeuralNode.add_inbound_connection(fake_from_node_id, weight)
    {:ok, {inbound_connections, _neuron_inbound_connection_two}} = NeuralNode.add_inbound_connection(inbound_connections_count_one, fake_from_node_id, weight)
    {:ok, neuron_test_helper_pid} = GenServer.start_link(NodeTestHelper,%NodeTestHelper{})
    outbound_connections = Neuron.add_outbound_connection_to_connections(neuron_test_helper_pid, fake_test_helper_connection_id)
    {:ok, _} = GenServer.start_link(Neuron,
      %Neuron{
        neuron_id: neuron_id,
        activation_function: activation_function_with_id,
        inbound_connections: inbound_connections,
        outbound_connections: outbound_connections
      }, name: neuron_id)
    artificial_synapse = %Synapse{value: 1.0, from_node_id: fake_from_node_id, connection_id: neuron_inbound_connection_id}
    :ok = GenServer.cast(neuron_id, {:receive_synapse, artificial_synapse})

    #TODO find a better way to wait for the async op
    :timer.sleep(5)
    updated_test_state = GenServer.call(neuron_test_helper_pid, :get_state)
    assert tuple_size(updated_test_state.received_synapses) == 0
  end

  test "Upon receiving a synapse, if the updated_barrier is full with two expected synapses then the Neuron should send a synapse to its outbound connections" do
    activation_function_with_id = {:sigmoid, &ActivationFunction.sigmoid/1}
    weight = 1.0
    neuron_id = :neuron
    fake_from_node_id = 5
    fake_test_helper_connection_id = 9
    {:ok, {inbound_connections_count_one, neuron_inbound_connection_id}} =
      NeuralNode.add_inbound_connection(fake_from_node_id, weight)
    {:ok, {inbound_connections, neuron_inbound_connection_two_id}} =
      NeuralNode.add_inbound_connection(inbound_connections_count_one, fake_from_node_id, weight)
    {:ok, neuron_test_helper_pid} = GenServer.start_link(NodeTestHelper,%NodeTestHelper{})
    outbound_connections = Neuron.add_outbound_connection_to_connections(neuron_test_helper_pid, fake_test_helper_connection_id)
    {:ok, _} = GenServer.start_link(Neuron,
      %Neuron{
        neuron_id: neuron_id,
        activation_function: activation_function_with_id,
        inbound_connections: inbound_connections,
        outbound_connections: outbound_connections
      }, name: neuron_id)

    artificial_synapse =
      %Synapse{value: 1.0, from_node_id: fake_from_node_id, connection_id: neuron_inbound_connection_id}
    artificial_synapse_two =
      %Synapse{value: 1.0, from_node_id: fake_from_node_id, connection_id: neuron_inbound_connection_two_id}
    :ok = GenServer.cast(neuron_id, {:receive_synapse, artificial_synapse})
    :ok = GenServer.cast(neuron_id, {:receive_synapse, artificial_synapse_two})

    #TODO find a better way to wait for the async op
    :timer.sleep(5)
    updated_test_state = GenServer.call(neuron_test_helper_pid, :get_state)
    assert tuple_size(updated_test_state.received_synapses) == 1

    {received_synapse} = updated_test_state.received_synapses
    assert received_synapse.connection_id == fake_test_helper_connection_id
    assert_in_delta received_synapse.value, 0.8807, 0.001
    assert received_synapse.from_node_id == neuron_id
  end

  test "Upon receiving a blank synapse, Neuron should not activate" do
    activation_function_with_id = {:sigmoid, &ActivationFunction.sigmoid/1}
    weight = 1.0
    neuron_id = :neuron
    fake_from_node_id = 5
    fake_test_helper_connection_id = 9
    {:ok, {inbound_connections, neuron_inbound_connection_id}} =
      NeuralNode.add_inbound_connection(fake_from_node_id, weight)
    {:ok, neuron_test_helper_pid} = GenServer.start_link(NodeTestHelper,%NodeTestHelper{})
    outbound_connections = Neuron.add_outbound_connection_to_connections(neuron_test_helper_pid, fake_test_helper_connection_id)
    {:ok, _} = GenServer.start_link(Neuron,
      %Neuron{
        neuron_id: neuron_id,
        activation_function: activation_function_with_id,
        inbound_connections: inbound_connections,
        outbound_connections: outbound_connections
      }, name: neuron_id)
    artificial_synapse = %Synapse{value: 1.0, from_node_id: fake_from_node_id, connection_id: neuron_inbound_connection_id}
    :ok = GenServer.call(neuron_id, {:receive_blank_synapse, artificial_synapse})

    #TODO find a better way to wait for the async op
    :timer.sleep(5)
    updated_test_state = GenServer.call(neuron_test_helper_pid, :get_state)
    assert tuple_size(updated_test_state.received_synapses) == 0
  end

  test "Upon receiving a blank synapse, Neuron should not activate with two inbound connections" do
    activation_function_with_id = {:sigmoid, &ActivationFunction.sigmoid/1}
    weight = 1.0
    neuron_id = :neuron
    fake_from_node_id = 5
    fake_test_helper_connection_id = 9
    {:ok, {inbound_connections_count_one, neuron_inbound_connection_id}} =
      NeuralNode.add_inbound_connection(fake_from_node_id, weight)
    {:ok, {inbound_connections, neuron_inbound_connection_two_id}} =
      NeuralNode.add_inbound_connection(inbound_connections_count_one, fake_from_node_id, weight)
    {:ok, neuron_test_helper_pid} = GenServer.start_link(NodeTestHelper,%NodeTestHelper{})
    outbound_connections = Neuron.add_outbound_connection_to_connections(neuron_test_helper_pid, fake_test_helper_connection_id)
    {:ok, _} = GenServer.start_link(Neuron,
      %Neuron{
        neuron_id: neuron_id,
        activation_function: activation_function_with_id,
        inbound_connections: inbound_connections,
        outbound_connections: outbound_connections
      }, name: neuron_id)
    artificial_synapse = %Synapse{value: 3.0, from_node_id: fake_from_node_id, connection_id: neuron_inbound_connection_id}
    artificial_synapse_two = %Synapse{value: 5.0, from_node_id: fake_from_node_id, connection_id: neuron_inbound_connection_two_id}
    :ok = GenServer.call(neuron_id, {:receive_blank_synapse, artificial_synapse})
    :ok = GenServer.call(neuron_id, {:receive_blank_synapse, artificial_synapse_two})

    #TODO find a better way to wait for the async op
    :timer.sleep(5)
    updated_test_state = GenServer.call(neuron_test_helper_pid, :get_state)
    assert tuple_size(updated_test_state.received_synapses) == 0
  end

  test "process_learning_for_neuron should handle the hebbian learning function" do
    learning_coefficient = 0.7
    learning_function = {:hebbian, learning_coefficient}

    fake_node_id_one = 5
    fake_node_one_connection_id_one = 1
    fake_node_one_connection_id_two = 3
    connections_from_node_one = %{
      fake_node_one_connection_id_one => 5.2,
      fake_node_one_connection_id_two => 1.2
    }

    fake_node_id_two = 2
    fake_node_two_connection_id_one = 9
    connections_from_node_two = %{
      fake_node_two_connection_id_one => -0.25
    }
    inbound_connections = %{
      fake_node_id_one => connections_from_node_one,
      fake_node_id_two => connections_from_node_two
    }

    full_barrier = %{
      {fake_node_id_one, fake_node_one_connection_id_one} => %Synapse{ value: 40.2},
      {fake_node_id_one, fake_node_one_connection_id_two} => %Synapse{ value: 4.25},
      {fake_node_id_two, fake_node_two_connection_id_one} => %Synapse{ value: 97.4}
    }

    outbound_synapse = 0.78

    updated_inbound_connections = Neuron.process_learning_for_neuron(learning_function, inbound_connections, full_barrier, outbound_synapse)

    assert updated_inbound_connections != inbound_connections
    assert Map.has_key?(updated_inbound_connections, fake_node_id_one)
    assert Map.has_key?(updated_inbound_connections, fake_node_id_two)

    updated_connections_from_node_one = Map.get(updated_inbound_connections, fake_node_id_one)
    assert Map.has_key?(updated_connections_from_node_one, fake_node_one_connection_id_one)
    assert Map.has_key?(updated_connections_from_node_one, fake_node_one_connection_id_two)

    updated_node_one_connection_id_one_weight = Map.get(updated_connections_from_node_one, fake_node_one_connection_id_one)
    assert updated_node_one_connection_id_one_weight == 9.421

    updated_node_one_connection_id_two_weight = Map.get(updated_connections_from_node_one, fake_node_one_connection_id_two)
    assert updated_node_one_connection_id_two_weight == 3.13375

    updated_connections_from_node_two = Map.get(updated_inbound_connections, fake_node_id_two)
    assert Map.has_key?(updated_connections_from_node_two, fake_node_two_connection_id_one)
    updated_node_two_connection_id_one_weight = Map.get(updated_connections_from_node_two, fake_node_two_connection_id_one)
    assert updated_node_two_connection_id_one_weight == -212.9716
  end

  test "process_learning_for_neuron should do nothing if the learning_function is nil" do
    learning_function = nil
    fake_node_id_one = 5
    fake_node_one_connection_id_one = 1
    fake_node_one_connection_id_two = 3
    connections_from_node_one = %{
      fake_node_one_connection_id_one => 5.2,
      fake_node_one_connection_id_two => 1.2
    }
    inbound_connections = %{
      fake_node_id_one => connections_from_node_one
    }

    full_barrier = %{
      {fake_node_id_one, fake_node_one_connection_id_one} => %Synapse{ value: 40.2},
      {fake_node_id_one, fake_node_one_connection_id_two} => %Synapse{ value: 4.25}
    }

    outbound_synapse = 0.78

    updated_inbound_connections = Neuron.process_learning_for_neuron(learning_function, inbound_connections, full_barrier, outbound_synapse)

    assert updated_inbound_connections == inbound_connections
  end

  test "Neuron should be able to handle hebbian learning function during operation" do
    learning_coefficient = 0.9
    learning_function = {:hebbian, learning_coefficient}
    activation_function_with_id = {:sigmoid, &ActivationFunction.sigmoid/1}
    weight = 1.0
    neuron_id = :neuron
    fake_from_node_id = 5
    fake_test_helper_connection_id = 9
    {:ok, {inbound_connections_count_one, neuron_inbound_connection_id}} =
      NeuralNode.add_inbound_connection(fake_from_node_id, weight)
    {:ok, {inbound_connections, neuron_inbound_connection_two_id}} =
      NeuralNode.add_inbound_connection(inbound_connections_count_one, fake_from_node_id, weight)
    {:ok, neuron_test_helper_pid} = GenServer.start_link(NodeTestHelper,%NodeTestHelper{})
    outbound_connections = Neuron.add_outbound_connection_to_connections(neuron_test_helper_pid, fake_test_helper_connection_id)
    {:ok, _} = GenServer.start_link(Neuron,
      %Neuron{
        neuron_id: neuron_id,
        activation_function: activation_function_with_id,
        inbound_connections: inbound_connections,
        outbound_connections: outbound_connections,
        learning_function: learning_function
      }, name: neuron_id)

    artificial_synapse =
      %Synapse{value: 1.0, from_node_id: fake_from_node_id, connection_id: neuron_inbound_connection_id}
    artificial_synapse_two =
      %Synapse{value: 1.0, from_node_id: fake_from_node_id, connection_id: neuron_inbound_connection_two_id}
    :ok = GenServer.cast(neuron_id, {:receive_synapse, artificial_synapse})
    :ok = GenServer.cast(neuron_id, {:receive_synapse, artificial_synapse_two})

    #TODO find a better way to wait for the async op
    :timer.sleep(5)
    updated_test_state = GenServer.call(neuron_test_helper_pid, :get_state)
    assert tuple_size(updated_test_state.received_synapses) == 1

    {received_synapse} = updated_test_state.received_synapses
    assert received_synapse.connection_id == fake_test_helper_connection_id
    assert_in_delta received_synapse.value, 0.8807, 0.001
    assert received_synapse.from_node_id == neuron_id

    :ok = GenServer.cast(neuron_id, {:receive_synapse, artificial_synapse})
    :ok = GenServer.cast(neuron_id, {:receive_synapse, artificial_synapse_two})

    :timer.sleep(5)
    updated_test_state = GenServer.call(neuron_test_helper_pid, :get_state)
    assert tuple_size(updated_test_state.received_synapses) == 2

    {_received_synapse, received_synapse} = updated_test_state.received_synapses
    assert received_synapse.connection_id == fake_test_helper_connection_id
    assert_in_delta received_synapse.value, 0.9730233, 0.001
    assert received_synapse.from_node_id == neuron_id

    :ok = GenServer.cast(neuron_id, {:receive_synapse, artificial_synapse})
    :ok = GenServer.cast(neuron_id, {:receive_synapse, artificial_synapse_two})

    :timer.sleep(5)
    updated_test_state = GenServer.call(neuron_test_helper_pid, :get_state)
    assert tuple_size(updated_test_state.received_synapses) == 3

    {_received_synapse, _received_synapse_two, received_synapse} = updated_test_state.received_synapses
    assert received_synapse.connection_id == fake_test_helper_connection_id
    assert_in_delta received_synapse.value, 0.99521, 0.001
    assert received_synapse.from_node_id == neuron_id
  end

  test "connect_neurons should connect two neurons together" do
    neuron_id_one = 1
    neuron_one = %Neuron{neuron_id: neuron_id_one}
    neuron_id_two = 2
    neuron_two = %Neuron{neuron_id: neuron_id_two}
    neuron_layer = 1
    neurons = %{
      neuron_layer => %{
        neuron_id_one => neuron_one,
        neuron_id_two => neuron_two
      }
    }
    weight = 20
    {:ok, neurons} = Neuron.connect_neurons(neurons, neuron_layer, neuron_id_one, neuron_layer, neuron_id_two, weight)
    {:ok, neuron_one} = Neuron.get_neuron(neurons, neuron_layer, neuron_id_one)
    {:ok, neuron_two} = Neuron.get_neuron(neurons, neuron_layer, neuron_id_two)
    connection_id = 1
    assert neuron_one.outbound_connections == %{{neuron_id_two, connection_id} => nil}
    assert neuron_two.inbound_connections == %{neuron_id_one => %{connection_id=>weight}}
  end

  test "disconnect_neurons should disconect two neuron" do
    neuron_id_one = 1
    neuron_one = %Neuron{neuron_id: neuron_id_one}
    neuron_id_two = 2
    neuron_two = %Neuron{neuron_id: neuron_id_two}
    neuron_layer = 1
    neurons = %{
      neuron_layer => %{
        neuron_id_one => neuron_one,
        neuron_id_two => neuron_two
      }
    }
    weight = 20
    {:ok, neurons} = Neuron.connect_neurons(neurons, neuron_layer, neuron_id_one, neuron_layer, neuron_id_two, weight)
    {:ok, neuron_one} = Neuron.get_neuron(neurons, neuron_layer, neuron_id_one)
    {:ok, neuron_two} = Neuron.get_neuron(neurons, neuron_layer, neuron_id_two)
    connection_id = 1
    assert neuron_one.outbound_connections == %{{neuron_id_two, connection_id} => nil}
    assert neuron_two.inbound_connections == %{neuron_id_one => %{connection_id=>weight}}
    {:ok, neurons} = Neuron.disconnect_neurons(neurons, neuron_layer, neuron_id_one, neuron_layer, neuron_id_two, connection_id)
    {:ok, neuron_one} = Neuron.get_neuron(neurons, neuron_layer, neuron_id_one)
    {:ok, neuron_two} = Neuron.get_neuron(neurons, neuron_layer, neuron_id_two)
    assert neuron_one.outbound_connections == Map.new()
    assert neuron_two.inbound_connections == Map.new()
  end

end
