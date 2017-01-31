defmodule Evolixir.CortexTest do
  use ExUnit.Case
  doctest Cortex

  test "is_connection_recursive? should check if the from_neuron's layer is greater than the to_neuron's layer" do
    neuron_one = %Neuron{neuron_id: 9}
    neuron_two = %Neuron{neuron_id: 6}
    neuron_one_layer = 1
    neuron_two_layer = 7
    neurons =
      %{
        neuron_one_layer => [neuron_one],
        neuron_two_layer => [neuron_two]
      }

    is_recursive? = CortexController.is_connection_recursive?(neurons, neuron_one_layer, neuron_two.neuron_id)

    assert is_recursive? == true
  end

  test "is_connection_recursive? should return false if it can't find the target node" do
    neuron_one = %Neuron{neuron_id: 9}
    neuron_two = %Neuron{neuron_id: 6}
    neuron_two_layer = 7
    neurons =
      %{
        neuron_two_layer => [neuron_two]
      }

    is_recursive? = CortexController.is_connection_recursive?(neurons, neuron_two_layer, neuron_one.neuron_id)

    assert is_recursive? == false
  end

  test "is_connection_recursive? should check if the from_neuron's layer is equal to the to_neuron's layer" do
    neuron_one = %Neuron{neuron_id: 9}
    neuron_two = %Neuron{neuron_id: 6}
    neuron_two_layer = 7
    neurons =
      %{
        neuron_two_layer => [neuron_one, neuron_two],
      }

    is_recursive? = CortexController.is_connection_recursive?(neurons, neuron_two_layer, neuron_one.neuron_id)

    assert is_recursive? == true
  end

  test "is_connection_recursive? should return false if the from_neuron_layer is less than the to_neuron's layer" do
    neuron_one = %Neuron{neuron_id: 9}
    neuron_two = %Neuron{neuron_id: 6}
    neuron_two_layer = 7
    neuron_one_layer = neuron_two_layer+4
    neurons =
      %{
        neuron_one_layer => [neuron_one],
        neuron_two_layer => [neuron_two]
      }

    is_recursive? = CortexController.is_connection_recursive?(neurons, neuron_one_layer, neuron_two.neuron_id)

    assert is_recursive? == false
  end

  test "set_recursive_neural_network_state should queue up blank synapses for recursive connections" do
    fake_recursive_neuron_id = 54
    fake_recursive_neuron_layer = 5
    fake_recursive_neuron = %Neuron{neuron_id: fake_recursive_neuron_id}

    {:ok, test_helper_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    {inbound_connections, inbound_connection_id} =
      NeuralNode.add_inbound_connection(Map.new(), fake_recursive_neuron_id, 1.5)
    fake_neuron_layer = fake_recursive_neuron_layer - 1
    fake_neuron = %Neuron {
      neuron_id: test_helper_pid,
      inbound_connections: inbound_connections
    }
    neurons =
      %{
        fake_neuron_layer => [fake_neuron],
        fake_recursive_neuron_layer => [fake_recursive_neuron]
      }

    registry_func = fn x -> x end

    CortexController.set_recursive_neural_network_state(registry_func, neurons)

    updated_test_state = GenServer.call(test_helper_pid, :get_state)
    assert tuple_size(updated_test_state.received_synapses) == 1

    {received_synapse} = updated_test_state.received_synapses
    assert received_synapse.connection_id == inbound_connection_id
    assert_in_delta received_synapse.value, 0.0, 0.001
    assert received_synapse.from_node_id == fake_recursive_neuron_id
  end

  test "set_recursive_neural_network_state should not queue up blank synapses for feed forward connections" do
    fake_recursive_neuron_id = 2
    fake_recursive_neuron_layer = 5
    fake_recursive_neuron = %Neuron{neuron_id: fake_recursive_neuron_id}

    {:ok, test_helper_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    {inbound_connections, _inbound_connection_id} =
      NeuralNode.add_inbound_connection(Map.new(), fake_recursive_neuron_id, 1.5)
    fake_neuron_layer = fake_recursive_neuron_layer + 1
    fake_neuron = %Neuron {
      neuron_id: test_helper_pid,
      inbound_connections: inbound_connections
    }
    neurons =
      %{
        fake_neuron_layer => [fake_neuron],
        fake_recursive_neuron_layer => [fake_recursive_neuron]
      }

    registry_func = fn x -> x end

    CortexController.set_recursive_neural_network_state(registry_func, neurons)

    updated_test_state = GenServer.call(test_helper_pid, :get_state)
    assert tuple_size(updated_test_state.received_synapses) == 0
  end

  test "set_recursive_neural_network_state should queue up blank synapses for recursive connections making it possible to activate a neuron" do
    fake_recursive_neuron_id = 90
    fake_recursive_neuron_layer = 9
    fake_recursive_neuron = %Neuron{neuron_id: fake_recursive_neuron_id}

    fake_neuron_id = 76
    fake_neuron_layer = 1
    fake_neuron = %Neuron{neuron_id: fake_neuron_id}

    {:ok, test_helper_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    fake_connection_id = 99
    outbound_connections = [{test_helper_pid, fake_connection_id}]

    {inbound_connections_count_one, _recursive_inbound_connection_id} =
      NeuralNode.add_inbound_connection(Map.new(), fake_recursive_neuron_id, 1.0)
    {inbound_connections, inbound_connection_id} =
      NeuralNode.add_inbound_connection(inbound_connections_count_one, fake_neuron_id, 1.5)

    activation_function_with_id = {:sigmoid, &ActivationFunction.sigmoid/1}
    neuron_layer = fake_neuron_layer+1
    neuron_id = :neuron
    neuron_one = %Neuron{
      activation_function: activation_function_with_id,
      neuron_id: neuron_id,
      inbound_connections: inbound_connections,
      outbound_connections: outbound_connections
    }
    {:ok, _} = GenServer.start_link(Neuron, neuron_one, name: neuron_id)

    neurons =
      %{
        fake_neuron_layer => [neuron_one],
        neuron_layer => [fake_neuron],
        fake_recursive_neuron_layer => [fake_recursive_neuron]
      }

    registry_func = fn x -> x end
    CortexController.set_recursive_neural_network_state(registry_func, neurons)

    artificial_synapse = %Synapse {
      value: 5.5,
      from_node_id: fake_neuron_id,
      connection_id: inbound_connection_id
    }

    :ok = GenServer.cast(neuron_id, {:receive_synapse, artificial_synapse})

    #TODO find a better way to wait for the async op
    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)
    assert tuple_size(updated_test_state.received_synapses) == 1

    {received_synapse} = updated_test_state.received_synapses
    assert received_synapse.connection_id == fake_connection_id
    assert_in_delta received_synapse.value, 0.9997, 0.001
    assert received_synapse.from_node_id == neuron_id
  end

  test "Cortex should synchronize a basic neural network" do
    neuron_id = 1
    sensor_id = 2
    actuator_id = 3
    {:ok, test_helper_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    {neuron_inbound_connections, inbound_neuron_connection_id} = NeuralNode.add_inbound_connection(Map.new(), sensor_id, 20.0)

    sync_function = {0, fn () -> [1.0] end}
    sensor_outbound_connections = NeuralNode.add_outbound_connection([], neuron_id, inbound_neuron_connection_id)
    sensor = %Sensor{
      outbound_connections: sensor_outbound_connections,
      sync_function: sync_function,
      sensor_id: sensor_id
    }

    {actuator_inbound_connections, inbound_actuator_connection_id} = NeuralNode.add_inbound_connection(Map.new(), neuron_id, 0.0)
    neuron_outbound_connections = NeuralNode.add_outbound_connection([], actuator_id, inbound_actuator_connection_id)

    activation_function_with_id = {:id, &ActivationFunction.id/1}
    neuron = %Neuron{
      neuron_id: neuron_id,
      bias: 10.0,
      activation_function: activation_function_with_id,
      inbound_connections: neuron_inbound_connections,
      outbound_connections: neuron_outbound_connections
    }

    actuator_function_with_id = {:test_actuator_function, fn output_value ->
      :ok = GenServer.call(test_helper_pid, {:activate, output_value})
    end}
    actuator = %Actuator{
      inbound_connections: actuator_inbound_connections,
      actuator_function: actuator_function_with_id,
      actuator_id: actuator_id
    }

    neurons = %{
      1 => [neuron]
    }
    actuators = [
      actuator
    ]
    sensors = [
      sensor
    ]

    registry_name = Cortex_Registry_Basic
    {:ok, _registry_pid} = Registry.start_link(:unique, registry_name)
    cortex_id = :cortex
    {:ok, _cortex_pid} = Cortex.start_link(registry_name, cortex_id, sensors, neurons, actuators)

    Cortex.think(registry_name, cortex_id)

    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, output_value} = updated_test_state.was_activated
    assert_in_delta output_value, 30.0, 0.001
  end

  test "Cortex should synchronize a basic recurrent neural network" do
    neuron_id = 1
    sensor_id = 2
    actuator_id = 3
    {:ok, test_helper_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    {neuron_inbound_connections_count_one, inbound_neuron_connection_id} = NeuralNode.add_inbound_connection(Map.new(), sensor_id, 1.59)
    {neuron_inbound_connections, inbound_recurrent_neuron_connection_id} = NeuralNode.add_inbound_connection(neuron_inbound_connections_count_one, neuron_id, 1.42)

    sync_function = {0, fn () -> [1.0,2.0,3.0] end}
    sensor_outbound_connections = NeuralNode.add_outbound_connection([], neuron_id, inbound_neuron_connection_id)
    sensor = %Sensor{
      outbound_connections: sensor_outbound_connections,
      sync_function: sync_function,
      sensor_id: sensor_id
    }

    {actuator_inbound_connections, inbound_actuator_connection_id} = NeuralNode.add_inbound_connection(Map.new(), neuron_id, 0.0)
    neuron_outbound_connections_count_one = NeuralNode.add_outbound_connection([], actuator_id, inbound_actuator_connection_id)
    neuron_outbound_connections = NeuralNode.add_outbound_connection(neuron_outbound_connections_count_one, neuron_id, inbound_recurrent_neuron_connection_id)

    activation_function_with_id = {:sigmoid, &ActivationFunction.sigmoid/1}
    neuron = %Neuron{
      neuron_id: neuron_id,
      activation_function: activation_function_with_id,
      inbound_connections: neuron_inbound_connections,
      outbound_connections: neuron_outbound_connections
    }

    actuator_function_with_id = {:test_actuator_function, fn output_value ->
      :ok = GenServer.call(test_helper_pid, {:activate, output_value})
    end}
    actuator = %Actuator{
      inbound_connections: actuator_inbound_connections,
      actuator_function: actuator_function_with_id,
      actuator_id: actuator_id
    }

    neurons = %{
      1 => [neuron]
    }
    actuators = [
      actuator
    ]
    sensors = [
      sensor
    ]

    registry_name = Cortex_Registry_Basic
    {:ok, _registry_pid} = Registry.start_link(:unique, registry_name)
    cortex_id = :cortex
    {:ok, _cortex_pid} = Cortex.start_link(registry_name, cortex_id, sensors, neurons, actuators)
    :ok = Cortex.reset_network(registry_name, cortex_id)

    Cortex.think(registry_name, cortex_id)

    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, output_value} = updated_test_state.was_activated
    assert_in_delta output_value, 0.830, 0.001

    Cortex.think(registry_name, cortex_id)
    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, output_value} = updated_test_state.was_activated
    assert_in_delta output_value, 0.941, 0.001
  end

  test "Cortex should be able to solve XNOR" do
    sensor_1_id = 1
    sensor_2_id = 2
    actuator_id = 3
    neuron_a2_1_id = 4
    neuron_a2_2_id = 5
    neuron_a3_1_id = 6
    {:ok, test_helper_pid} =
      GenServer.start_link(NodeTestHelper, %NodeTestHelper{})

    weight_one = 20.0
    weight_two = -20.0
    {neuron_a2_1_inbound_connections_count_one, sensor_1_to_a2_1_connection_id} =
      NeuralNode.add_inbound_connection(Map.new(),
        sensor_1_id, weight_one)
    {neuron_a2_1_inbound_connections, sensor_2_to_a2_1_connection_id} =
      NeuralNode.add_inbound_connection(neuron_a2_1_inbound_connections_count_one,
        sensor_2_id, weight_one)

    {neuron_a2_2_inbound_connections_count_one, sensor_1_to_a2_2_connection_id} =
      NeuralNode.add_inbound_connection(Map.new(),
        sensor_1_id, weight_two)
    {neuron_a2_2_inbound_connections, sensor_2_to_a2_2_connection_id} =
      NeuralNode.add_inbound_connection(neuron_a2_2_inbound_connections_count_one,
        sensor_2_id, weight_two)

    neuron_weight = 20.0
    {neuron_a3_1_inbound_connections_count_one, neuron_a2_1_to_a3_1_connection_id} =
      NeuralNode.add_inbound_connection(Map.new(),
        neuron_a2_1_id, neuron_weight)
    {neuron_a3_1_inbound_connections, neuron_a2_2_to_a3_1_connection_id} =
      NeuralNode.add_inbound_connection(neuron_a3_1_inbound_connections_count_one,
        neuron_a2_2_id, neuron_weight)

    {actuator_inbound_connections, neuron_a3_1_to_actuator_connection_id} =
      NeuralNode.add_inbound_connection(Map.new(),
        neuron_a3_1_id, 0.0)

    neuron_a2_1_outbound_connections =
      NeuralNode.add_outbound_connection([],
        neuron_a3_1_id, neuron_a2_1_to_a3_1_connection_id)
    neuron_a2_2_outbound_connections =
      NeuralNode.add_outbound_connection([],
        neuron_a3_1_id, neuron_a2_2_to_a3_1_connection_id)

    neuron_a3_1_outbound_connections =
      NeuralNode.add_outbound_connection([],
        actuator_id, neuron_a3_1_to_actuator_connection_id)

    sensor_1_data = [
      [0.0, 0.0],
      [0.0, 0.0],
      [1.0, 1.0],
      [1.0, 1.0]
    ]
    {:ok, sensor_data_gen_pid} = GenServer.start_link(DataGenerator, sensor_1_data)
    sensor_1_sync_function = {0, fn () -> GenServer.call(sensor_data_gen_pid, :pop) end}
    sensor_1_outbound_connections_count_one =
      NeuralNode.add_outbound_connection([],
        neuron_a2_1_id, sensor_1_to_a2_1_connection_id)
    sensor_1_outbound_connections =
      NeuralNode.add_outbound_connection(
        sensor_1_outbound_connections_count_one,
        neuron_a2_2_id,
        sensor_1_to_a2_2_connection_id)
    sensor_1 = %Sensor{
      outbound_connections: sensor_1_outbound_connections,
      sync_function: sensor_1_sync_function,
      sensor_id: sensor_1_id
    }

    sensor_2_data = [
      [0.0, 0.0],
      [1.0, 1.0],
      [0.0, 0.0],
      [1.0, 1.0]
    ]
    {:ok, sensor_data_2_gen_pid} = GenServer.start_link(DataGenerator, sensor_2_data)
    sensor_2_sync_function = {1, fn () -> GenServer.call(sensor_data_2_gen_pid, :pop) end}
    sensor_2_outbound_connections_count_one =
      NeuralNode.add_outbound_connection([],
        neuron_a2_1_id, sensor_2_to_a2_1_connection_id)
    sensor_2_outbound_connections =
      NeuralNode.add_outbound_connection(sensor_2_outbound_connections_count_one,
        neuron_a2_2_id, sensor_2_to_a2_2_connection_id)
    sensor_2 = %Sensor{
      outbound_connections: sensor_2_outbound_connections,
      sync_function: sensor_2_sync_function,
      sensor_id: sensor_2_id
    }

    activation_function_with_id = {:sigmoid, &ActivationFunction.sigmoid/1}
    neuron_a2_1 = %Neuron{
      neuron_id: neuron_a2_1_id,
      activation_function: activation_function_with_id,
      inbound_connections: neuron_a2_1_inbound_connections,
      outbound_connections: neuron_a2_1_outbound_connections,
      bias: -30.0
    }
    neuron_a2_2 = %Neuron{
      neuron_id: neuron_a2_2_id,
      activation_function: activation_function_with_id,
      inbound_connections: neuron_a2_2_inbound_connections,
      outbound_connections: neuron_a2_2_outbound_connections,
      bias: 10.0
    }
    neuron_a3_1 = %Neuron{
      neuron_id: neuron_a3_1_id,
      activation_function: activation_function_with_id,
      inbound_connections: neuron_a3_1_inbound_connections,
      outbound_connections: neuron_a3_1_outbound_connections,
      bias: -10.0
    }

    actuator_function_with_id = {:test_actuator_function, fn output_value ->
      :ok = GenServer.call(test_helper_pid, {:activate, output_value})
    end}
    actuator = %Actuator{
      inbound_connections: actuator_inbound_connections,
      actuator_function: actuator_function_with_id,
      actuator_id: actuator_id
    }

    neurons = %{
      1 => [neuron_a2_1, neuron_a2_2],
      2 => [neuron_a3_1]
    }
    actuators = [
      actuator
    ]
    sensors = [
      sensor_1,
      sensor_2
    ]

    registry_name = Cortex_XNOR
    {:ok, _registry_pid} = Registry.start_link(:unique, registry_name)
    cortex_id = :cortex
    {:ok, _cortex_pid} = Cortex.start_link(registry_name, cortex_id, sensors, neurons, actuators)
    :ok = Cortex.reset_network(registry_name, cortex_id)

    Cortex.think(registry_name, cortex_id)

    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, output_value} = updated_test_state.was_activated
    assert output_value > 0.99

    Cortex.think(registry_name, cortex_id)
    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, output_value} = updated_test_state.was_activated
    assert output_value < 0.01

    Cortex.think(registry_name, cortex_id)
    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, output_value} = updated_test_state.was_activated
    assert output_value < 0.01

    Cortex.think(registry_name, cortex_id)
    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, output_value} = updated_test_state.was_activated
    assert output_value > 0.99
  end


end
