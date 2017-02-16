defmodule Evolixir.HyperbolicTimeChamber do
  use ExUnit.Case
  doctest HyperbolicTimeChamber

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
    actuator_function = fn ->
      fn _neural_output ->
        IO.puts "output!"
      end
    end
    actuator_sources = %{
      actuator_function_id => actuator_function
    }

    sync_function_id = 1
    sync_function_source = fn ->
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
    IO.inspect mutated_generation
    assert mutated_generation != old_generation
  end

end
