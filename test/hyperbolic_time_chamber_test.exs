defmodule Evolixir.HyperbolicTimeChamber do
  use ExUnit.Case
  doctest HyperbolicTimeChamber

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
    sensor = %Sensor{
      sensor_id: 1,
    }

    neuron = %Neuron{
      neuron_id: 2
    }
    actuator = %Actuator{
      actuator_id: 3
    }

    {sensor, neuron} =
      Sensor.connect_to_neuron(sensor, neuron, 0.0)

    {neuron, actuator} =
      Neuron.connect_to_actuator(neuron, actuator)

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
    sensor = %Sensor{
      sensor_id: 1,
      sync_function: sync_function_id
    }

    neuron = %Neuron{
      neuron_id: 2,
      activation_function: {activation_function_id, activation_function}
    }
    actuator = %Actuator{
      actuator_id: 3,
      actuator_function: actuator_function_id
    }

    {sensor, neuron} =
      Sensor.connect_to_neuron(sensor, neuron, 0.0)

    {neuron, actuator} =
      Neuron.connect_to_actuator(neuron, actuator)

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

    :ok = HyperbolicTimeChamber.think_and_act(chamber_pid)
    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, output_value} = updated_test_state.was_activated
    assert output_value != nil

    :ok = HyperbolicTimeChamber.think_and_act(chamber_pid)
    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, new_output_value} = updated_test_state.was_activated
    assert new_output_value != nil

    :ok = HyperbolicTimeChamber.think_and_act(chamber_pid)
    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, latest_output_value} = updated_test_state.was_activated
    assert latest_output_value != nil
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
    sensor = %Sensor{
      sensor_id: 1,
      sync_function: sync_function_id
    }

    neuron = %Neuron{
      neuron_id: 2,
      activation_function: {activation_function_id, activation_function}
    }
    actuator = %Actuator{
      actuator_id: 3,
      actuator_function: actuator_function_id
    }

    {sensor, neuron} =
      Sensor.connect_to_neuron(sensor, neuron, 0.0)

    {neuron, actuator} =
      Neuron.connect_to_actuator(neuron, actuator)

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

    :ok = HyperbolicTimeChamber.think_and_act(chamber_pid)
    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, output_value} = updated_test_state.was_activated
    assert output_value != nil

    :ok = HyperbolicTimeChamber.think_and_act(chamber_pid)
    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, output_value} = updated_test_state.was_activated
    assert output_value != nil
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
    sensor = %Sensor{
      sensor_id: 1,
      sync_function: sync_function_id
    }

    neuron = %Neuron{
      neuron_id: 2,
      activation_function: {activation_function_id, activation_function}
    }
    actuator = %Actuator{
      actuator_id: 3,
      actuator_function: actuator_function_id
    }

    {sensor, neuron} =
      Sensor.connect_to_neuron(sensor, neuron, 0.0)

    {neuron, actuator} =
      Neuron.connect_to_actuator(neuron, actuator)

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

    :ok = HyperbolicTimeChamber.think_and_act(chamber_pid)
    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, output_value} = updated_test_state.was_activated
    assert output_value != nil

    :ok = HyperbolicTimeChamber.think_and_act(chamber_pid)
    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, output_value} = updated_test_state.was_activated
    assert output_value != nil

    :ok = HyperbolicTimeChamber.think_and_act(chamber_pid)
    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, output_value} = updated_test_state.was_activated
    assert output_value != nil

    :ok = HyperbolicTimeChamber.think_and_act(chamber_pid)
    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, output_value} = updated_test_state.was_activated
    assert output_value != nil
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
    sensor = %Sensor{
      sensor_id: 1,
      sync_function: sync_function_id
    }

    neuron = %Neuron{
      neuron_id: 2,
      activation_function: {activation_function_id, activation_function}
    }
    actuator = %Actuator{
      actuator_id: 3,
      actuator_function: actuator_function_id
    }

    {sensor, neuron} =
      Sensor.connect_to_neuron(sensor, neuron, 0.0)

    {neuron, actuator} =
      Neuron.connect_to_actuator(neuron, actuator)

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
      assert Enum.count(scored_generation_records) > 0
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

    :ok = HyperbolicTimeChamber.think_and_act(chamber_pid)
    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, output_value} = updated_test_state.was_activated
    assert output_value != nil

    :ok = HyperbolicTimeChamber.think_and_act(chamber_pid)
    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, new_output_value} = updated_test_state.was_activated
    assert new_output_value != nil

    :ok = HyperbolicTimeChamber.think_and_act(chamber_pid)
    :timer.sleep(5)
    updated_test_state = GenServer.call(test_helper_pid, :get_state)

    {true, latest_output_value} = updated_test_state.was_activated
    assert latest_output_value != nil
  end

end
