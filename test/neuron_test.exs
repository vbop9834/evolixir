defmodule Evolixir.NeuronTest do
  use ExUnit.Case
  doctest Neuron

  test "apply_weight_to_syntax should multiply the weight by the synapse value and return an updated weighted synapse" do
    synapse = %Synapse{value: 1.0}
    inbound_connection_weight = 5.0
    weighted_synapse = Neuron.apply_weight_to_synapse(synapse, inbound_connection_weight)
    assert weighted_synapse.value == 5.0
  end

  test ":add_inbound_connection message should return :ok if successful" do
    {:ok, neuron_pid} = GenServer.start_link(Neuron, %Neuron{})
    from_node_pid = 0
    weight = 0.0
    {returned_atom, connection_id} = GenServer.call(neuron_pid, {:add_inbound_connection, {from_node_pid, weight}})
    assert returned_atom == :ok
    assert connection_id == 1
  end

  test ":add_outbound_connection message should return :ok if successful" do
    {:ok, neuron_pid} = GenServer.start_link(Neuron, %Neuron{})
    to_node_pid = 0
    connection_id = 1
    returned_atom = GenServer.call(neuron_pid, {:add_outbound_connection, {to_node_pid, connection_id}})
    assert returned_atom == :ok
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
    {:ok, neuron_test_helper_pid} = GenServer.start_link(NodeTestHelper,%NodeTestHelper{})
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
    {:ok, neuron_test_helper_pid} = GenServer.start_link(NodeTestHelper,%NodeTestHelper{})
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
    {:ok, neuron_test_helper_pid} = GenServer.start_link(NodeTestHelper,%NodeTestHelper{})

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
