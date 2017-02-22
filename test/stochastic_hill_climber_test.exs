defmodule Evolixir.StochasticHillClimberTest do
  use ExUnit.Case
  doctest StochasticHillClimber

  test "perturb_weights_in_neural_network should generate perturbed topologies" do
    sensor_id = 1
    sensor = %Sensor{
      sensor_id: sensor_id
    }
    neuron_id = 2
    neuron = %Neuron{
      neuron_id: neuron_id
    }

    neuron_id_two = 3
    neuron_two = %Neuron{
      neuron_id: neuron_id_two
    }
    actuator_id = 4
    actuator = %Actuator{
      actuator_id: actuator_id
    }

    {sensor, neuron} = Sensor.connect_to_neuron(sensor, neuron, 5.0)
    {sensor, neuron} = Sensor.connect_to_neuron(sensor, neuron, 5.0)
    {sensor, neuron} = Sensor.connect_to_neuron(sensor, neuron, 5.0)
    {sensor, neuron} = Sensor.connect_to_neuron(sensor, neuron, 5.0)
    {sensor, neuron} = Sensor.connect_to_neuron(sensor, neuron, 5.0)
    {sensor, neuron} = Sensor.connect_to_neuron(sensor, neuron, 5.0)

    {sensor, neuron_two} = Sensor.connect_to_neuron(sensor, neuron_two, 5.0)
    {sensor, neuron_two} = Sensor.connect_to_neuron(sensor, neuron_two, 5.0)
    {sensor, neuron_two} = Sensor.connect_to_neuron(sensor, neuron_two, 5.0)

    {neuron, neuron_two} = Neuron.connect_neurons(neuron, neuron_two, 10.0)
    {neuron, neuron_two} = Neuron.connect_neurons(neuron, neuron_two, 10.0)
    {neuron, neuron_two} = Neuron.connect_neurons(neuron, neuron_two, 10.0)
    {neuron, neuron_two} = Neuron.connect_neurons(neuron, neuron_two, 10.0)

    {neuron, actuator} = Neuron.connect_to_actuator(neuron, actuator)

    sensors = %{
      sensor_id => sensor
    }
    neuron_layer = 1
    neurons = %{
      neuron_layer => %{
        neuron_id => neuron,
        neuron_id_two => neuron_two
      }
    }
    actuators = %{
      actuator_id => actuator
    }

    neural_network = {sensors, neurons, actuators}
    max_attempts_possible = 10
    perturbed_neural_networks = StochasticHillClimber.perturb_weights_in_neural_network(neural_network, max_attempts_possible)

    test_perturbed_neural_networks = fn perturbed_neural_network ->
      assert perturbed_neural_network != neural_network
    end

    Enum.each(perturbed_neural_networks, test_perturbed_neural_networks)
  end

end
