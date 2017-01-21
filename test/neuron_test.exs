defmodule Evolixir.NeuronTest do
  use ExUnit.Case
  doctest Neuron

  test "is_barrier_full? Should return true if barrier is full" do
    connection_id = 9
    weight = 2.0
    connections_from_node_one = Map.put(Map.new(), connection_id, weight)
    from_node_id = 1
    inbound_connections =
      %{
        from_node_id => connections_from_node_one
      }
    barrier =
      %{
        {from_node_id, connection_id} => %Synapse{}
      }
    barrier_is_full =
      Neuron.is_barrier_full?(barrier, inbound_connections)

    assert barrier_is_full == true
  end

  test "is_barrier_full? Should return true if barrier is not full" do
    fake_inbound_connection_id = 1
    fake_inbound_connection_id_two = 2
    connections_from_node_one =
      %{
        fake_inbound_connection_id => 0.0,
        fake_inbound_connection_id_two => 0.2
      }
    inbound_connections =
      %{
        1 => connections_from_node_one
      }
    barrier =
      %{
        1 => %Synapse{}
      }
    barrier_is_full =
      Neuron.is_barrier_full?(barrier, inbound_connections)

    assert barrier_is_full == false
  end

  test "apply_weight_to_syntax should multiply the weight by the synapse value and return an updated weighted synapse" do
    synapse = %Synapse{value: 1.0}
    inbound_connection_weight = 5.0
    weighted_synapse = Neuron.apply_weight_to_synapse(synapse, inbound_connection_weight)
    assert weighted_synapse.value == 5.0
  end

  test "add_inbound_connections should add the supplied pid and weight as an inbound connection" do
    empty_inbound_connections = Map.new()
    from_node_pid = 5
    weight = 2.3
    {inbound_connections_with_new_inbound, new_connection_id} = Neuron.add_inbound_connection(empty_inbound_connections, from_node_pid, weight)

    connections_from_node_pid = Map.get(inbound_connections_with_new_inbound, from_node_pid)

    assert new_connection_id == 1
    assert Enum.count(connections_from_node_pid) == 1
    assert Map.has_key?(connections_from_node_pid, new_connection_id) == true

    connection_weight = Map.get(connections_from_node_pid, new_connection_id)
    assert connection_weight == weight
  end

  test "add_outbound_connection should add an outbound connection" do
    outbound_connections = []
    to_node_pid = 3
    connection_id = 1
    updated_outbound_connections = Neuron.add_outbound_connection(outbound_connections, to_node_pid, connection_id)

    assert Enum.count(updated_outbound_connections) == 1

    [{outbound_connection_to_pid, outbound_connection_id}] = updated_outbound_connections
    assert outbound_connection_to_pid == to_node_pid
    assert connection_id == outbound_connection_id
  end

  test ":add_outbound_connection message should return :ok if successful" do
    {:ok, neuron_pid} = GenServer.start_link(Neuron, %Neuron{})
    to_node_pid = 0
    connection_id = 1
    returned_atom = GenServer.call(neuron_pid, {:add_outbound_connection, {to_node_pid, connection_id}})
    assert returned_atom == :ok
  end

  test ":add_inbound_connection message should return :ok if successful" do
    {:ok, neuron_pid} = GenServer.start_link(Neuron, %Neuron{})
    from_node_pid = 0
    weight = 0.0
    {returned_atom, connection_id} = GenServer.call(neuron_pid, {:add_inbound_connection, {from_node_pid, weight}})
    assert returned_atom == :ok
    assert connection_id == 1
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
    output_value = Neuron.calculate_output_value(barrier, activation_function)

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
    output_value = Neuron.calculate_output_value(barrier, activation_function)

    expected_value = (first_synapse.value + second_synapse.value) |> activation_function.()
    assert output_value == expected_value
  end

  test "Upon receiving a synapse, if the updated_barrier is full then the Neuron should send a synapse to its outbound connections" do
    {:ok, neuron_pid} = GenServer.start_link(Neuron, %Neuron{activation_function: &ActivationFunction.sigmoid/1})
    {:ok, neuron_test_helper_pid} = GenServer.start_link(NeuronTestHelper,%NeuronTestHelper{})
    fake_from_node_id = 5
    weight = 1.0
    fake_test_helper_connection_id = 9
    {:ok, neuron_inbound_connection_id} = GenServer.call(neuron_pid, {:add_inbound_connection, {fake_from_node_id, weight}})
    :ok = GenServer.call(neuron_pid, {:add_outbound_connection, {neuron_test_helper_pid, fake_test_helper_connection_id}})
    artificial_synapse = %Synapse{value: 1.0, from_node_id: fake_from_node_id, connection_id: neuron_inbound_connection_id}
    :ok = GenServer.cast(neuron_pid, {:receive_synapse, artificial_synapse})

    #TODO find a better way to wait for the async op
    :timer.sleep(50)
    updated_test_state = GenServer.call(neuron_test_helper_pid, :get_state)
    assert tuple_size(updated_test_state.received_synapses) == 1

    {received_synapse} = updated_test_state.received_synapses
    assert received_synapse.connection_id == fake_test_helper_connection_id
    assert_in_delta received_synapse.value, 0.7310, 0.001
    assert received_synapse.from_node_id == neuron_pid
  end

  test "Upon receiving a synapse, if the updated_barrier is not full then the Neuron should not send a synapse to its outbound connections" do
    {:ok, neuron_pid} = GenServer.start_link(Neuron, %Neuron{activation_function: &ActivationFunction.sigmoid/1})
    {:ok, neuron_test_helper_pid} = GenServer.start_link(NeuronTestHelper,%NeuronTestHelper{})
    fake_from_node_id = 5
    weight = 1.0
    fake_test_helper_connection_id = 9
    #Add two expected connections
    {:ok, neuron_inbound_connection_id} = GenServer.call(neuron_pid, {:add_inbound_connection, {fake_from_node_id, weight}})
    {:ok, _neuron_inbound_connection_two_id} = GenServer.call(neuron_pid, {:add_inbound_connection, {fake_from_node_id, weight}})
    :ok = GenServer.call(neuron_pid, {:add_outbound_connection, {neuron_test_helper_pid, fake_test_helper_connection_id}})

    artificial_synapse = %Synapse{value: 1.0, from_node_id: fake_from_node_id, connection_id: neuron_inbound_connection_id}
    :ok = GenServer.cast(neuron_pid, {:receive_synapse, artificial_synapse})

    #TODO find a better way to wait for the async op
    :timer.sleep(5)
    updated_test_state = GenServer.call(neuron_test_helper_pid, :get_state)
    assert tuple_size(updated_test_state.received_synapses) == 0
  end

  test "Upon receiving a synapse, if the updated_barrier is full with two expected synapses then the Neuron should send a synapse to its outbound connections" do
    {:ok, neuron_pid} = GenServer.start_link(Neuron, %Neuron{activation_function: &ActivationFunction.sigmoid/1})
    {:ok, neuron_test_helper_pid} = GenServer.start_link(NeuronTestHelper,%NeuronTestHelper{})

    fake_from_node_id = 5
    weight = 1.0
    fake_test_helper_connection_id = 9
    {:ok, neuron_inbound_connection_id} =
      GenServer.call(neuron_pid, {:add_inbound_connection, {fake_from_node_id, weight}})
    {:ok, neuron_inbound_connection_two_id} =
      GenServer.call(neuron_pid, {:add_inbound_connection, {fake_from_node_id, weight}})
    :ok = GenServer.call(neuron_pid, {:add_outbound_connection, {neuron_test_helper_pid, fake_test_helper_connection_id}})

    artificial_synapse =
      %Synapse{value: 1.0, from_node_id: fake_from_node_id, connection_id: neuron_inbound_connection_id}
    artificial_synapse_two =
      %Synapse{value: 1.0, from_node_id: fake_from_node_id, connection_id: neuron_inbound_connection_two_id}
    :ok = GenServer.cast(neuron_pid, {:receive_synapse, artificial_synapse})
    :ok = GenServer.cast(neuron_pid, {:receive_synapse, artificial_synapse_two})

    #TODO find a better way to wait for the async op
    :timer.sleep(5)
    updated_test_state = GenServer.call(neuron_test_helper_pid, :get_state)
    assert tuple_size(updated_test_state.received_synapses) == 1

    {received_synapse} = updated_test_state.received_synapses
    assert received_synapse.connection_id == fake_test_helper_connection_id
    assert_in_delta received_synapse.value, 0.8807, 0.001
    assert received_synapse.from_node_id == neuron_pid
  end
end
