defmodule Evolixir.HyperbolicTimeChamber do
  use ExUnit.Case
  doctest HyperbolicTimeChamber

  test "get_select_fit_population_function should return a function that selects a top percentage of scored neural networks" do
    percentage_to_keep = 50
    select_fit_population_function = HyperbolicTimeChamber.get_select_fit_population_function(percentage_to_keep)
    cortex_id_one = 1
    cortex_id_two = 5
    score_one = 50
    score_two = 25
    neural_network_one = :nn_one
    neural_network_two = :nn_two
    scored_generation_records = [
      {score_one, cortex_id_one, neural_network_one},
      {score_two, cortex_id_two, neural_network_two},
    ]

    fit_population = select_fit_population_function.(scored_generation_records)
    assert Enum.count(fit_population) == 1
    assert Map.has_key?(fit_population, cortex_id_one) == true
    fit_neural_network = Map.get(fit_population, cortex_id_one)
    assert fit_neural_network == neural_network_one
  end

  test "get_select_fit_population_function should return a function that selects a top percentage of scored neural networks and sorts through scored perturbed networks" do
    percentage_to_keep = 50
    select_fit_population_function = HyperbolicTimeChamber.get_select_fit_population_function(percentage_to_keep)
    cortex_id_one = 1
    cortex_id_two = 5
    perturb_id_one = 1
    perturb_id_two = 2
    score_one_perturb_one = 50
    score_one_perturb_two = 250
    score_two_perturb_one = 25
    score_two_perturb_two = 5
    neural_network_one_perturb_one = :nn_one
    neural_network_one_perturb_two = :nn_one_perturb_two
    neural_network_two_perturb_one = :nn_two
    neural_network_two_perturb_two = :nn_two_perturb_two
    scored_generation_records = [
      {score_one_perturb_one, {cortex_id_one, perturb_id_one}, neural_network_one_perturb_one},
      {score_one_perturb_two, {cortex_id_one, perturb_id_two}, neural_network_one_perturb_two},
      {score_two_perturb_one, {cortex_id_two, perturb_id_one}, neural_network_two_perturb_one},
      {score_two_perturb_two, {cortex_id_two, perturb_id_two}, neural_network_two_perturb_two}
    ]

    fit_population = select_fit_population_function.(scored_generation_records)
    assert Enum.count(fit_population) == 1
    assert Map.has_key?(fit_population, cortex_id_one) == true
    fit_neural_network = Map.get(fit_population, cortex_id_one)
    assert fit_neural_network == neural_network_one_perturb_two
  end

  test "hook_actuators_up_to_source should hook actuators into actuator function sources" do
    cortex_id = :unique_cortex
    actuator_function = :actuator_function
    actuator_function_source = fn cortex_id_requesting_actuator_function ->
      assert cortex_id_requesting_actuator_function == cortex_id
      actuator_function
    end
    actuator_function_id = 1
    actuator_sources = %{
      actuator_function_id => actuator_function_source
    }

    actuator_id = :actuator
    actuator = %Actuator{
      actuator_id: actuator_id,
      actuator_function: actuator_function_id
    }
    actuator_id_two = :actuator_two
    actuator_two = %Actuator{
      actuator_id: actuator_id_two,
      actuator_function: actuator_function_id
    }
    actuators = %{
      actuator_id => actuator,
      actuator_id_two => actuator_two
    }

    updated_actuators = HyperbolicTimeChamber.hook_actuators_up_to_source(actuator_sources, cortex_id, actuators)

    assert Map.has_key?(updated_actuators, actuator_id)
    updated_actuator = Map.get(updated_actuators, actuator_id)
    assert updated_actuator != actuator
    assert updated_actuator.actuator_function == {actuator_function_id, actuator_function}

    assert Map.has_key?(updated_actuators, actuator_id_two)
    updated_actuator = Map.get(updated_actuators, actuator_id_two)
    assert updated_actuator != actuator_two
    assert updated_actuator.actuator_function == {actuator_function_id, actuator_function}
  end

  test "hook_actuators_up_to_source should hook actuators into actuator function sources even if the actuator already has a function" do
    cortex_id = :unique_cortex
    actuator_function = :actuator_function
    actuator_function_source = fn cortex_id_requesting_actuator_function ->
      assert cortex_id_requesting_actuator_function == cortex_id
      actuator_function
    end
    actuator_function_id = 1
    actuator_sources = %{
      actuator_function_id => actuator_function_source
    }

    actuator_id = :actuator
    actuator = %Actuator{
      actuator_id: {actuator_id, actuator_function},
      actuator_function: actuator_function_id
    }
    actuators = %{
      actuator_id => actuator
    }

    updated_actuators = HyperbolicTimeChamber.hook_actuators_up_to_source(actuator_sources, cortex_id, actuators)
    assert Map.has_key?(updated_actuators, actuator_id)
    updated_actuator = Map.get(updated_actuators, actuator_id)
    assert updated_actuator.actuator_function == {actuator_function_id, actuator_function}
  end

  test "hook_sensors_up_to_source should hook sensors into sync function sources" do
    cortex_id = :cortex
    sync_function_id = :sync_id
    sync_function = :sync_function
    sync_function_source = fn cortex_id_requesting_sync_function ->
      assert cortex_id_requesting_sync_function == cortex_id
      sync_function
    end

    sync_sources = %{
      sync_function_id => sync_function_source
    }

    sensor_id = :sensor
    sensor = %Sensor{
      sensor_id: sensor_id,
      sync_function: sync_function_id
    }

    sensors = %{
      sensor_id => sensor
    }

    updated_sensors = HyperbolicTimeChamber.hook_sensors_up_to_source(sync_sources, cortex_id, sensors)
    assert Map.has_key?(updated_sensors, sensor_id)
    updated_sensor = Map.get(updated_sensors, sensor_id)
    assert updated_sensor != sensor
    assert updated_sensor.sync_function == {sync_function_id, sync_function}
  end

  test "hook_sensors_up_to_source should hook sensors into sync function sources even if the sensor already has a function" do
    cortex_id = :cortex
    sync_function_id = :sync_id
    sync_function = :sync_function
    sync_function_source = fn cortex_id_requesting_sync_function ->
      assert cortex_id_requesting_sync_function == cortex_id
      sync_function
    end

    sync_sources = %{
      sync_function_id => sync_function_source
    }

    sensor_id = :sensor
    sensor = %Sensor{
      sensor_id: sensor_id,
      sync_function: {sync_function_id, sync_function}
    }

    sensors = %{
      sensor_id => sensor
    }

    updated_sensors = HyperbolicTimeChamber.hook_sensors_up_to_source(sync_sources, cortex_id, sensors)
    assert Map.has_key?(updated_sensors, sensor_id)
    updated_sensor = Map.get(updated_sensors, sensor_id)
    assert updated_sensor.sync_function == {sync_function_id, sync_function}
  end

  test "evolve should mutate a generation" do
    sensor_id = 1
    sensor = %Sensor{
      sensor_id: sensor_id
    }

    neuron_id = 2
    neuron = %Neuron{
      neuron_id: neuron_id
    }
    actuator_id = 3
    actuator = %Actuator{
      actuator_id: actuator_id
    }

    sensors = %{
      sensor_id => sensor
    }
    neuron_layer = 1
    neurons = %{
      neuron_layer => %{ neuron_id => neuron }
    }
    actuators = %{
      actuator_id => actuator
    }

    weight = 0.0
    {:ok, {sensors, neurons}} =
      Sensor.connect_to_neuron(sensors, neurons, sensor_id, neuron_layer, neuron_id, weight)

    {:ok, {neurons, actuators}} =
      Actuator.connect_neuron_to_actuator(neurons, actuators, neuron_layer, neuron_id, actuator_id)

    cortex_id = 1
    neural_network = {sensors, neurons, actuators}
    scored_records = [
      {50, cortex_id, neural_network}
    ]

    actuator_function_id = 1
    actuator_function = fn _cortex_id ->
      fn _neural_output ->
        IO.puts "output!"
      end
    end
    actuator_sources = %{
      actuator_function_id => actuator_function
    }

    sync_function_id = 1
    sync_function_source = fn _cortex_id ->
      fn ->
        [0, 1, 2]
      end
    end
    sync_function_sources = %{
      sync_function_id => sync_function_source
    }

    activation_function_id = :sigmoid
    activation_function =
      &ActivationFunction.sigmoid/1
    activation_functions = %{
      activation_function_id => activation_function
    }
    minds_per_generation = 5
    possible_mutations = Mutations.default_mutation_sequence

    select_fit_population_function = HyperbolicTimeChamber.get_select_fit_population_function(50)

    hyperbolic_time_chamber_properties = %HyperbolicTimeChamber{
      actuator_sources: actuator_sources,
      sync_sources: sync_function_sources,
      activation_functions: activation_functions,
      minds_per_generation: minds_per_generation,
      possible_mutations: possible_mutations,
      select_fit_population_function: select_fit_population_function
    }

    mutated_generation = HyperbolicTimeChamber.evolve(hyperbolic_time_chamber_properties, scored_records)

    old_generation = %{
      cortex_id => neural_network
    }
    assert mutated_generation != old_generation
    assert Enum.count(mutated_generation) == minds_per_generation
  end

  test "HyperbolicTimeChamber process should let the fitness function handle brain termination" do
    {:ok, test_helper_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    actuator_function_id = 1
    actuator_function = fn _cortex_id ->
      fn neural_output ->
        GenServer.call(test_helper_pid, {:activate, neural_output})
      end
    end
    actuator_sources = %{
      actuator_function_id => actuator_function
    }

    sync_function_id = 1
    sync_function_source = fn _cortex_id ->
      fn ->
        [1, 2, 3]
      end
    end
    sync_function_sources = %{
      sync_function_id => sync_function_source
    }

    activation_function_id = :sigmoid
    activation_function =
      &ActivationFunction.sigmoid/1
    activation_functions = %{
      activation_function_id => activation_function
    }
    sensor_id = 1
    sensor = %Sensor{
      sensor_id: sensor_id,
      sync_function: sync_function_id
    }

    neuron_id = 2
    neuron = %Neuron{
      neuron_id: neuron_id,
      activation_function: {activation_function_id, activation_function}
    }
    actuator_id = 3
    actuator = %Actuator{
      actuator_id: actuator_id,
      actuator_function: actuator_function_id
    }

    sensors = %{
      sensor_id => sensor
    }
    neuron_layer = 1
    neurons = %{
      neuron_layer => %{ neuron_id => neuron }
    }
    actuators = %{
      actuator_id => actuator
    }

    weight = 0.0
    {:ok, {sensors,neurons}} =
      Sensor.connect_to_neuron(sensors, neurons, sensor_id, neuron_layer, neuron_id, weight)

    {:ok, {neurons, actuators}} =
      Actuator.connect_neuron_to_actuator(neurons, actuators, neuron_layer, neuron_id, actuator_id)

    cortex_id = 1
    neural_network = {sensors, neurons, actuators}
    starting_records = %{
      cortex_id => neural_network
    }

    chamber_name = :test_chamber
    minds_per_generation = 5
    possible_mutations =
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

    select_fit_population_function = HyperbolicTimeChamber.get_select_fit_population_function(50)

    fitness_function =
      fn _cortex_id ->
        {:end_think_cycle, :random.uniform()}
      end

    hyperbolic_time_chamber_properties = %HyperbolicTimeChamber{
      fitness_function: fitness_function,
      actuator_sources: actuator_sources,
      sync_sources: sync_function_sources,
      activation_functions: activation_functions,
      minds_per_generation: minds_per_generation,
      possible_mutations: possible_mutations,
      select_fit_population_function: select_fit_population_function,
      starting_generation_records: starting_records
    }

    {:ok, chamber_pid} = HyperbolicTimeChamber.start_link(chamber_name, hyperbolic_time_chamber_properties)

    think_timeout = 5000
    Enum.each(Enum.to_list(1..100), fn _ ->
      :ok = HyperbolicTimeChamber.think_and_act(chamber_pid, think_timeout)
      :timer.sleep(5)
      updated_test_state = GenServer.call(test_helper_pid, :get_state)

      {true, output_value} = updated_test_state.was_activated
      assert output_value != nil
    end)
  end

  test "HyperbolicTimeChamber process should continue to process think cycles with continue_think_cycle in the fitness function" do
    {:ok, test_helper_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    actuator_function_id = 1
    actuator_function = fn _cortex_id ->
      fn neural_output ->
        GenServer.call(test_helper_pid, {:activate, neural_output})
      end
    end
    actuator_sources = %{
      actuator_function_id => actuator_function
    }

    sync_function_id = 1
    sync_function_source = fn _cortex_id ->
      fn ->
        [1, 2, 3]
      end
    end
    sync_function_sources = %{
      sync_function_id => sync_function_source
    }

    activation_function_id = :sigmoid
    activation_function =
      &ActivationFunction.sigmoid/1
    activation_functions = %{
      activation_function_id => activation_function
    }
    sensor_id = 1
    sensor = %Sensor{
      sensor_id: sensor_id,
      sync_function: sync_function_id
    }

    neuron_id = 2
    neuron = %Neuron{
      neuron_id: neuron_id,
      activation_function: {activation_function_id, activation_function}
    }
    actuator_id = 3
    actuator = %Actuator{
      actuator_id: actuator_id,
      actuator_function: actuator_function_id
    }

    sensors = %{
      sensor.sensor_id => sensor
    }
    neuron_layer = 1
    neurons = %{
      neuron_layer => %{ neuron.neuron_id => neuron }
    }
    actuators = %{
      actuator.actuator_id => actuator
    }

    weight = 0.0
    {:ok, {sensors, neurons}} =
      Sensor.connect_to_neuron(sensors, neurons, sensor_id, neuron_layer, neuron_id, weight)

    {:ok, {neurons, actuators}} =
      Actuator.connect_neuron_to_actuator(neurons, actuators, neuron_layer, neuron_id, actuator_id)

    cortex_id = 1
    neural_network = {sensors, neurons, actuators}
    starting_records = %{
      cortex_id => neural_network
    }

    chamber_name = :test_chamber
    minds_per_generation = 5
    possible_mutations = Mutations.default_mutation_sequence

    select_fit_population_function = HyperbolicTimeChamber.get_select_fit_population_function(50)

    fitness_function =
      fn _cortex_id ->
        {:continue_think_cycle, :random.uniform()}
      end

    hyperbolic_time_chamber_properties = %HyperbolicTimeChamber{
      fitness_function: fitness_function,
      actuator_sources: actuator_sources,
      sync_sources: sync_function_sources,
      activation_functions: activation_functions,
      minds_per_generation: minds_per_generation,
      possible_mutations: possible_mutations,
      select_fit_population_function: select_fit_population_function,
      starting_generation_records: starting_records
    }

    {:ok, chamber_pid} = HyperbolicTimeChamber.start_link(chamber_name, hyperbolic_time_chamber_properties)

    think_timeout = 5000
    Enum.each(Enum.to_list(1..100), fn _ ->
      :ok = HyperbolicTimeChamber.think_and_act(chamber_pid, think_timeout)
      :timer.sleep(5)
      updated_test_state = GenServer.call(test_helper_pid, :get_state)

      {true, output_value} = updated_test_state.was_activated
      assert output_value != nil
    end)
  end

  test "HyperbolicTimeChamber process should allow perturbing weights in topologies" do
    {:ok, test_helper_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    actuator_function_id = 1
    actuator_function = fn _cortex_id ->
      fn neural_output ->
        GenServer.call(test_helper_pid, {:activate, neural_output})
      end
    end
    actuator_sources = %{
      actuator_function_id => actuator_function
    }

    sync_function_id = 1
    sync_function_source = fn _cortex_id ->
      fn ->
        [1, 2, 3]
      end
    end
    sync_function_sources = %{
      sync_function_id => sync_function_source
    }

    activation_function_id = :sigmoid
    activation_function =
      &ActivationFunction.sigmoid/1
    activation_functions = %{
      activation_function_id => activation_function
    }
    sensor_id = 1
    sensor = %Sensor{
      sensor_id: sensor_id,
      sync_function: sync_function_id
    }

    neuron_id = 2
    neuron = %Neuron{
      neuron_id: neuron_id,
      activation_function: {activation_function_id, activation_function}
    }
    actuator_id = 3
    actuator = %Actuator{
      actuator_id: actuator_id,
      actuator_function: actuator_function_id
    }

    sensors = %{
      sensor_id => sensor
    }
    neuron_layer = 1
    neurons = %{
      neuron_layer => %{ neuron_id => neuron }
    }
    actuators = %{
      actuator_id => actuator
    }

    weight = 0.0
    {:ok, {sensors, neurons}} =
      Sensor.connect_to_neuron(sensors, neurons, sensor_id, neuron_layer, neuron_id, weight)
    {:ok, {neurons, actuators}} =
      Actuator.connect_neuron_to_actuator(neurons, actuators, neuron_layer, neuron_id, actuator_id)
    cortex_id = 1
    neural_network = {sensors, neurons, actuators}
    starting_records = %{
      cortex_id => neural_network
    }

    chamber_name = :test_chamber
    minds_per_generation = 1
    possible_mutations = Mutations.default_mutation_sequence

    select_fit_population_function = HyperbolicTimeChamber.get_select_fit_population_function(50)

    fitness_function =
      fn {cortex_id, perturb_id} ->
        assert cortex_id > 0
        assert perturb_id >= 0
        {:continue_think_cycle, :random.uniform()}
      end

    hyperbolic_time_chamber_properties = %HyperbolicTimeChamber{
      fitness_function: fitness_function,
      actuator_sources: actuator_sources,
      sync_sources: sync_function_sources,
      activation_functions: activation_functions,
      minds_per_generation: minds_per_generation,
      possible_mutations: possible_mutations,
      select_fit_population_function: select_fit_population_function,
      starting_generation_records: starting_records,
      max_attempts_to_perturb: 10
    }

    {:ok, chamber_pid} = HyperbolicTimeChamber.start_link(chamber_name, hyperbolic_time_chamber_properties)

    think_timeout = 5000
    Enum.each(Enum.to_list(1..100), fn _ ->
      :ok = HyperbolicTimeChamber.think_and_act(chamber_pid, think_timeout)
      :timer.sleep(5)
      updated_test_state = GenServer.call(test_helper_pid, :get_state)

      {true, output_value} = updated_test_state.was_activated
      assert output_value != nil
    end)
  end

  test "HyperbolicTimeChamber process should have an end_of_generation_function" do
    {:ok, test_helper_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    actuator_function_id = 1
    actuator_function = fn _cortex_id ->
      fn neural_output ->
        GenServer.call(test_helper_pid, {:activate, neural_output})
      end
    end
    actuator_sources = %{
      actuator_function_id => actuator_function
    }

    sync_function_id = 1
    sync_function_source = fn _cortex_id ->
      fn ->
        [1, 2, 3]
      end
    end
    sync_function_sources = %{
      sync_function_id => sync_function_source
    }

    activation_function_id = :sigmoid
    activation_function =
      &ActivationFunction.sigmoid/1
    activation_functions = %{
      activation_function_id => activation_function
    }
    sensor_id = 1
    sensor = %Sensor{
      sensor_id: sensor_id,
      sync_function: sync_function_id
    }

    neuron_id = 2
    neuron = %Neuron{
      neuron_id: neuron_id,
      activation_function: {activation_function_id, activation_function}
    }
    actuator_id = 3
    actuator = %Actuator{
      actuator_id: actuator_id,
      actuator_function: actuator_function_id
    }

    weight = 0.0

    sensors = %{
      sensor.sensor_id => sensor
    }
    neuron_layer = 1
    neurons = %{
      neuron_layer => %{ neuron.neuron_id => neuron }
    }
    actuators = %{
      actuator.actuator_id => actuator
    }

    {:ok, {sensors, neurons}} =
      Sensor.connect_to_neuron(sensors, neurons, sensor_id, neuron_layer, neuron_id, weight)

    {:ok, {neurons, actuators}} =
      Actuator.connect_neuron_to_actuator(neurons, actuators, neuron_layer, neuron_id, actuator_id)

    cortex_id = 1
    neural_network = {sensors, neurons, actuators}
    starting_records = %{
      cortex_id => neural_network
    }

    chamber_name = :test_chamber
    minds_per_generation = 1
    possible_mutations = Mutations.default_mutation_sequence

    select_fit_population_function = HyperbolicTimeChamber.get_select_fit_population_function(50)

    end_of_generation_function = fn scored_generation_records ->
      assert Enum.count(scored_generation_records) == 1
      {score, cortex_id, _neural_network} = hd scored_generation_records
      assert score > 0
      assert cortex_id == 1
    end

    fitness_function =
      fn _cortex_id ->
        {:end_think_cycle, :random.uniform()}
      end

    hyperbolic_time_chamber_properties = %HyperbolicTimeChamber{
      fitness_function: fitness_function,
      actuator_sources: actuator_sources,
      sync_sources: sync_function_sources,
      activation_functions: activation_functions,
      minds_per_generation: minds_per_generation,
      possible_mutations: possible_mutations,
      select_fit_population_function: select_fit_population_function,
      starting_generation_records: starting_records,
      end_of_generation_function: end_of_generation_function
    }

    {:ok, chamber_pid} = HyperbolicTimeChamber.start_link(chamber_name, hyperbolic_time_chamber_properties)

    think_timeout = 5000
    Enum.each(Enum.to_list(1..100), fn _ ->
      :ok = HyperbolicTimeChamber.think_and_act(chamber_pid, think_timeout)
      :timer.sleep(5)
      updated_test_state = GenServer.call(test_helper_pid, :get_state)

      {true, output_value} = updated_test_state.was_activated
      assert output_value != nil
    end)
  end

  test "HyperbolicTimeChamber process should have a learning_function for neurons" do
    {:ok, test_helper_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    actuator_function_id = 1
    actuator_function = fn _cortex_id ->
      fn neural_output ->
        GenServer.call(test_helper_pid, {:activate, neural_output})
      end
    end
    actuator_sources = %{
      actuator_function_id => actuator_function
    }

    sync_function_id = 1
    sync_function_source = fn _cortex_id ->
      fn ->
        [1, 2, 3]
      end
    end
    sync_function_sources = %{
      sync_function_id => sync_function_source
    }

    activation_function_id = :sigmoid
    activation_function =
      &ActivationFunction.sigmoid/1
    activation_functions = %{
      activation_function_id => activation_function
    }
    sensor_id = 1
    sensor = %Sensor{
      sensor_id: sensor_id,
      sync_function: sync_function_id
    }

    learning_function = {:hebbian, 0.7}
    neuron_id = 2
    neuron = %Neuron{
      learning_function: learning_function,
      neuron_id: neuron_id,
      activation_function: {activation_function_id, activation_function}
    }
    actuator_id = 3
    actuator = %Actuator{
      actuator_id: actuator_id,
      actuator_function: actuator_function_id
    }

    weight = 0.0

    sensors = %{
      sensor.sensor_id => sensor
    }
    neuron_layer = 1
    neurons = %{
      neuron_layer => %{ neuron.neuron_id => neuron }
    }
    actuators = %{
      actuator.actuator_id => actuator
    }

    {:ok, {sensors, neurons}} =
      Sensor.connect_to_neuron(sensors, neurons, sensor_id, neuron_layer, neuron_id, weight)

    {:ok, {neurons, actuators}} =
      Actuator.connect_neuron_to_actuator(neurons, actuators, neuron_layer, neuron_id, actuator_id)

    cortex_id = 1
    neural_network = {sensors, neurons, actuators}
    starting_records = %{
      cortex_id => neural_network
    }

    chamber_name = :test_chamber
    minds_per_generation = 1
    possible_mutations = Mutations.default_mutation_sequence

    select_fit_population_function = HyperbolicTimeChamber.get_select_fit_population_function(50)

    end_of_generation_function = fn scored_generation_records ->
      assert Enum.count(scored_generation_records) == 1
      {score, cortex_id, _neural_network} = hd scored_generation_records
      assert score > 0
      assert cortex_id == 1
    end

    fitness_function =
      fn _cortex_id ->
        {:end_think_cycle, :random.uniform()}
      end

    hyperbolic_time_chamber_properties = %HyperbolicTimeChamber{
      learning_function: learning_function,
      fitness_function: fitness_function,
      actuator_sources: actuator_sources,
      sync_sources: sync_function_sources,
      activation_functions: activation_functions,
      minds_per_generation: minds_per_generation,
      possible_mutations: possible_mutations,
      select_fit_population_function: select_fit_population_function,
      starting_generation_records: starting_records,
      end_of_generation_function: end_of_generation_function
    }

    {:ok, chamber_pid} = HyperbolicTimeChamber.start_link(chamber_name, hyperbolic_time_chamber_properties)

    think_timeout = 5000
    Enum.each(Enum.to_list(1..100), fn _ ->
      :ok = HyperbolicTimeChamber.think_and_act(chamber_pid, think_timeout)
      :timer.sleep(5)
      updated_test_state = GenServer.call(test_helper_pid, :get_state)

      {true, output_value} = updated_test_state.was_activated
      assert output_value != nil
    end)
  end

end
