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
        neuron_one_layer => %{
          neuron_one.neuron_id => neuron_one
        },
        neuron_two_layer => %{
          neuron_two.neuron_id => neuron_two
        }
      }

    is_recursive? = CortexController.is_connection_recursive?(neurons, neuron_one_layer, neuron_two.neuron_id)

    assert is_recursive? == true
  end

  test "is_connection_recursive? should return error if it can't find the target node" do
    neuron_one = %Neuron{neuron_id: 9}
    neuron_two = %Neuron{neuron_id: 6}
    neuron_two_layer = 7
    neurons =
      %{
        neuron_two_layer => %{
          neuron_two.neuron_id => neuron_two
        }
      }

    {result, _reason} = CortexController.is_connection_recursive?(neurons, neuron_two_layer, neuron_one.neuron_id)

    assert result == :error
  end

  test "is_connection_recursive? should check if the from_neuron's layer is equal to the to_neuron's layer" do
    neuron_one = %Neuron{neuron_id: 9}
    neuron_two = %Neuron{neuron_id: 6}
    neuron_two_layer = 7
    neurons =
      %{
        neuron_two_layer => %{
          neuron_one.neuron_id => neuron_one,
          neuron_two.neuron_id => neuron_two
        },
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
        neuron_one_layer => %{
          neuron_one.neuron_id => neuron_one
        },
        neuron_two_layer => %{
          neuron_two.neuron_id => neuron_two
        }
      }

    is_recursive? = CortexController.is_connection_recursive?(neurons, neuron_one_layer, neuron_two.neuron_id)

    assert is_recursive? == false
  end

  test "set_recursive_neural_network_state should queue up blank synapses for recursive connections" do
    fake_recursive_neuron_id = 54
    fake_recursive_neuron_layer = 5
    fake_recursive_neuron = %Neuron{neuron_id: fake_recursive_neuron_id}

    {:ok, test_helper_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    {:ok, {inbound_connections, inbound_connection_id}} =
      NeuralNode.add_inbound_connection(Map.new(), fake_recursive_neuron_id, 1.5)
    fake_neuron_layer = fake_recursive_neuron_layer - 1
    fake_neuron = %Neuron {
      neuron_id: test_helper_pid,
      inbound_connections: inbound_connections
    }
    neurons =
      %{
        fake_neuron_layer => %{
          fake_neuron.neuron_id => fake_neuron
        },
        fake_recursive_neuron_layer => %{
          fake_recursive_neuron.neuron_id => fake_recursive_neuron
        }
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
    {:ok, {inbound_connections, _inbound_connection_id}} =
      NeuralNode.add_inbound_connection(Map.new(), fake_recursive_neuron_id, 1.5)
    fake_neuron_layer = fake_recursive_neuron_layer + 1
    fake_neuron = %Neuron {
      neuron_id: test_helper_pid,
      inbound_connections: inbound_connections
    }
    neurons =
      %{
        fake_neuron_layer => %{
          fake_neuron.neuron_id => fake_neuron
        },
        fake_recursive_neuron_layer => %{
          fake_recursive_neuron.neuron_id => fake_recursive_neuron
        }
      }

    registry_func = fn x -> x end

    CortexController.set_recursive_neural_network_state(registry_func, neurons)

    updated_test_state = GenServer.call(test_helper_pid, :get_state)
    assert tuple_size(updated_test_state.received_synapses) == 0
  end

  test "set_recursive_neural_network_state should queue up blank synapses for recursive connections making it possible to activate a neuron" do

    registry_name = :set_rec_test_registry
    {:ok, _pid} = Registry.start_link(:unique, registry_name)
    registry_func = fn x -> {:via, Registry, {registry_name, x}} end
    #Create node test helper for hooking into neurons
    fake_neuron_id = 0
    #Create Neurons
    activation_function = {:sigmoid, &ActivationFunction.sigmoid/1}
    neuron_one_id = (:random.uniform() * 10 + 1) |> round
    neuron_layer_one = 1
    neuron_one = %Neuron{
      registry_func: registry_func,
      activation_function: activation_function,
      neuron_id: neuron_one_id
    }

    neuron_two_id = neuron_one_id + 1
    neuron_layer_two = neuron_layer_one + 1
    neuron_two = %Neuron{
      registry_func: registry_func,
      activation_function: activation_function,
      neuron_id: neuron_two_id
    }

    neuron_layer_three = neuron_layer_two + 1
    neuron_three_id = neuron_two_id + 1
    neuron_three = %Neuron{
      registry_func: registry_func,
      activation_function: activation_function,
      neuron_id: neuron_three_id,
    }

    neurons =
      %{
        neuron_layer_one => %{
           neuron_one_id => neuron_one
        },
        neuron_layer_two => %{
          neuron_two_id => neuron_two
        },
        neuron_layer_three => %{
          neuron_three_id=> neuron_three
        }
      }

    #Hook test helper into Neuron one
    {:ok, {fake_connection_id, neurons}} = Neuron.add_inbound_connection(neurons, fake_neuron_id, neuron_layer_one, neuron_one_id, 1.0)

    #Neuron Order
    # 1 -> 3 -> 2
    # 1 -> 2
    {:ok, neurons} = Neuron.connect_neurons(neurons, neuron_layer_one, neuron_one_id, neuron_layer_three, neuron_three_id, 10.0)
    {:ok, neurons} = Neuron.connect_neurons(neurons, neuron_layer_one, neuron_one_id, neuron_layer_two, neuron_two_id, 10.0)
    {:ok, neurons} = Neuron.connect_neurons(neurons, neuron_layer_three, neuron_three_id, neuron_layer_two, neuron_two_id, 10.0)

    #Create Neuron One
    {:ok, neuron_one} = Neuron.get_neuron(neurons, neuron_layer_one, neuron_one_id)
    {:ok, _pid} = Neuron.start_link(neuron_one)
    #Create Neuron two as test helper
    neuron_two_name = registry_func.(neuron_two_id)
    {:ok, _pid} = NodeTestHelper.start_link(neuron_two_name)
    #Create Neuron three
    {:ok, neuron_three} = Neuron.get_neuron(neurons, neuron_layer_three, neuron_three_id)
    {:ok, _pid} = Neuron.start_link(neuron_three)

    CortexController.set_recursive_neural_network_state(registry_func, neurons)

    artificial_synapse = %Synapse {
      value: 10.0,
      from_node_id: fake_neuron_id,
      connection_id: fake_connection_id
    }

    :ok = Neuron.send_synapse_to_outbound_connection(artificial_synapse, neuron_one_id, registry_func)

    :timer.sleep(5)
    updated_test_state = GenServer.call(neuron_two_name, :get_state)
    assert tuple_size(updated_test_state.received_synapses) == 3

    #Retrieve stored Synapses
    {recursive_synapse, first_synapse, second_synapse} = updated_test_state.received_synapses
    #Test recursive synapse
    assert recursive_synapse.connection_id == fake_connection_id
    assert_in_delta recursive_synapse.value, 0.0, 0.001
    assert recursive_synapse.from_node_id == neuron_three_id
    #Test first synapse
    assert first_synapse.connection_id == fake_connection_id
    assert_in_delta first_synapse.value, 0.9997, 0.001
    assert first_synapse.from_node_id == neuron_one_id
    #Test second synapse
    assert second_synapse.connection_id == fake_connection_id
    assert_in_delta second_synapse.value, 0.9997, 0.001
    assert second_synapse.from_node_id == neuron_three_id
  end

  test "Cortex should synchronize a basic neural network" do
    neuron_id = 1
    sensor_id = 2
    actuator_id = 3
    {:ok, test_helper_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})

    sync_function = {0, fn () -> [1.0] end}
    sensor = %Sensor{
      sync_function: sync_function,
      sensor_id: sensor_id
    }

    activation_function_with_id = {:id, &ActivationFunction.id/1}
    neuron = %Neuron{
      neuron_id: neuron_id,
      bias: 10.0,
      activation_function: activation_function_with_id
    }

    actuator_function_with_id = {:test_actuator_function, fn output_value ->
      :ok = GenServer.call(test_helper_pid, {:activate, output_value})
    end}
    actuator = %Actuator{
      actuator_function: actuator_function_with_id,
      actuator_id: actuator_id
    }

    neuron_layer = 1
    neurons = %{
      neuron_layer => %{
        neuron.neuron_id => neuron
      }
    }
    actuators = %{
      actuator_id => actuator
    }
    sensors = %{
      sensor_id => sensor
    }
    {:ok, {sensors, neurons}} = Sensor.connect_to_neuron(sensors, neurons, sensor_id, neuron_layer, neuron_id, 20.0)
    {:ok, {neurons, actuators}} = Actuator.connect_neuron_to_actuator(neurons, actuators, neuron_layer, neuron_id, actuator_id)

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

    sync_function = {0, fn () -> [1.0,2.0,3.0] end}
    sensor = %Sensor{
      sync_function: sync_function,
      sensor_id: sensor_id
    }
    sensors = %{
      sensor.sensor_id => sensor
    }

    activation_function_with_id = {:sigmoid, &ActivationFunction.sigmoid/1}
    neuron = %Neuron{
      neuron_id: neuron_id,
      activation_function: activation_function_with_id
    }
    neuron_layer = 1
    neurons = %{
      neuron_layer => %{
        neuron.neuron_id => neuron
      }
    }

    actuator_function_with_id = {:test_actuator_function, fn output_value ->
      :ok = GenServer.call(test_helper_pid, {:activate, output_value})
    end}
    actuator = %Actuator{
      actuator_function: actuator_function_with_id,
      actuator_id: actuator_id
    }
    actuators = %{
      actuator.actuator_id => actuator
    }

    weight = 1.59
    {:ok, {sensors, neurons}} = Sensor.connect_to_neuron(sensors, neurons, sensor_id, neuron_layer, neuron_id, weight)
    weight = 1.42
    {:ok, neurons} = Neuron.connect_neurons(neurons, neuron_layer, neuron_id, neuron_layer, neuron_id, weight)
    {:ok, {neurons, actuators}} = Actuator.connect_neuron_to_actuator(neurons, actuators, neuron_layer, neuron_id, actuator_id)

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
    sensor_1_data = [
      [0.0, 0.0],
      [0.0, 0.0],
      [1.0, 1.0],
      [1.0, 1.0]
    ]
    {:ok, sensor_data_gen_pid} = GenServer.start_link(DataGenerator, sensor_1_data)
    sensor_1_sync_function = {0, fn () -> GenServer.call(sensor_data_gen_pid, :pop) end}
    sensor_1 = %Sensor{
      sync_function: sensor_1_sync_function,
      sensor_id: sensor_1_id
    }

    sensor_2_id = 2
    sensor_2_data = [
      [0.0, 0.0],
      [1.0, 1.0],
      [0.0, 0.0],
      [1.0, 1.0]
    ]
    {:ok, sensor_data_2_gen_pid} = GenServer.start_link(DataGenerator, sensor_2_data)
    sensor_2_sync_function = {1, fn () -> GenServer.call(sensor_data_2_gen_pid, :pop) end}
    sensor_2 = %Sensor{
      sync_function: sensor_2_sync_function,
      sensor_id: sensor_2_id
    }
    sensors = %{
      sensor_1.sensor_id => sensor_1,
      sensor_2.sensor_id => sensor_2
    }

    {:ok, test_helper_pid} =
      GenServer.start_link(NodeTestHelper, %NodeTestHelper{})

    activation_function_with_id = {:sigmoid, &ActivationFunction.sigmoid/1}
    neuron_a2_1_id = 4
    neuron_a2_1 = %Neuron{
      neuron_id: neuron_a2_1_id,
      activation_function: activation_function_with_id,
      bias: -30.0
    }
    neuron_a2_2_id = 5
    neuron_a2_2 = %Neuron{
      neuron_id: neuron_a2_2_id,
      activation_function: activation_function_with_id,
      bias: 10.0
    }
    neuron_a3_1_id = 6
    neuron_a3_1 = %Neuron{
      neuron_id: neuron_a3_1_id,
      activation_function: activation_function_with_id,
      bias: -10.0
    }

    neuron_layer_a2 = 1
    neuron_layer_a3 = 2
    neurons = %{
      neuron_layer_a2 => %{
        neuron_a2_1.neuron_id => neuron_a2_1,
        neuron_a2_2.neuron_id => neuron_a2_2
      },
      neuron_layer_a3 => %{
        neuron_a3_1.neuron_id => neuron_a3_1
      }
    }

    actuator_id = 3
    actuator_function_with_id = {:test_actuator_function, fn output_value ->
      :ok = GenServer.call(test_helper_pid, {:activate, output_value})
    end}
    actuator = %Actuator{
      actuator_function: actuator_function_with_id,
      actuator_id: actuator_id
    }

    actuators = %{
      actuator.actuator_id => actuator
    }

    #Connect sensors
    twenty_weight = 20.0
    negative_twenty_weight = -20.0
    {:ok, {sensors, neurons}} = Sensor.connect_to_neuron(sensors, neurons, sensor_1_id, neuron_layer_a2, neuron_a2_1_id, twenty_weight)
    {:ok, {sensors, neurons}} = Sensor.connect_to_neuron(sensors, neurons, sensor_1_id, neuron_layer_a2, neuron_a2_2_id, negative_twenty_weight)
    {:ok, {sensors, neurons}} = Sensor.connect_to_neuron(sensors, neurons, sensor_2_id, neuron_layer_a2, neuron_a2_1_id, twenty_weight)
    {:ok, {sensors, neurons}} = Sensor.connect_to_neuron(sensors, neurons, sensor_2_id, neuron_layer_a2, neuron_a2_2_id, negative_twenty_weight)
    #Connect neurons
    neuron_weight = 20.0
    {:ok, neurons} = Neuron.connect_neurons(neurons, neuron_layer_a2, neuron_a2_1_id, neuron_layer_a3, neuron_a3_1_id, neuron_weight)
    {:ok, neurons} = Neuron.connect_neurons(neurons, neuron_layer_a2, neuron_a2_2_id, neuron_layer_a3, neuron_a3_1_id, neuron_weight)
    #Connect actuator
    {:ok, {neurons, actuators}} = Actuator.connect_neuron_to_actuator(neurons, actuators, neuron_layer_a3, neuron_a3_1_id, actuator_id)

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
