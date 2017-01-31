defmodule Evolixir.NeuronTest do
  use ExUnit.Case
  doctest Neuron

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
    {inbound_connections, neuron_inbound_connection_id} = NeuralNode.add_inbound_connection(Map.new(), fake_from_node_id, weight)
    neuron_test_helper_pid = :test_helper
    {:ok, _} = GenServer.start_link(NodeTestHelper,%NodeTestHelper{}, name: neuron_test_helper_pid)
    outbound_connections = NeuralNode.add_outbound_connection([], neuron_test_helper_pid, fake_test_helper_connection_id)
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
    {inbound_connections_count_one, neuron_inbound_connection_id} = NeuralNode.add_inbound_connection(Map.new(), fake_from_node_id, weight)
    {inbound_connections, _neuron_inbound_connection_two} = NeuralNode.add_inbound_connection(inbound_connections_count_one, fake_from_node_id, weight)
    {:ok, neuron_test_helper_pid} = GenServer.start_link(NodeTestHelper,%NodeTestHelper{})
    outbound_connections = NeuralNode.add_outbound_connection([], neuron_test_helper_pid, fake_test_helper_connection_id)
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
    {inbound_connections_count_one, neuron_inbound_connection_id} = NeuralNode.add_inbound_connection(Map.new(), fake_from_node_id, weight)
    {inbound_connections, neuron_inbound_connection_two_id} = NeuralNode.add_inbound_connection(inbound_connections_count_one, fake_from_node_id, weight)
    {:ok, neuron_test_helper_pid} = GenServer.start_link(NodeTestHelper,%NodeTestHelper{})
    outbound_connections = NeuralNode.add_outbound_connection([], neuron_test_helper_pid, fake_test_helper_connection_id)
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
    {inbound_connections, neuron_inbound_connection_id} = NeuralNode.add_inbound_connection(Map.new(), fake_from_node_id, weight)
    {:ok, neuron_test_helper_pid} = GenServer.start_link(NodeTestHelper,%NodeTestHelper{})
    outbound_connections = NeuralNode.add_outbound_connection([], neuron_test_helper_pid, fake_test_helper_connection_id)
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
    {inbound_connections_count_one, neuron_inbound_connection_id} = NeuralNode.add_inbound_connection(Map.new(), fake_from_node_id, weight)
    {inbound_connections, neuron_inbound_connection_two_id} = NeuralNode.add_inbound_connection(inbound_connections_count_one, fake_from_node_id, weight)
    {:ok, neuron_test_helper_pid} = GenServer.start_link(NodeTestHelper,%NodeTestHelper{})
    outbound_connections = NeuralNode.add_outbound_connection([], neuron_test_helper_pid, fake_test_helper_connection_id)
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
end
