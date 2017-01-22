defmodule Cortex do
  use Supervisor
  defstruct sensors: [],
    neurons: Map.new(),
    actuators: []

  def start_link(sensors, neurons, actuators) do
    Supervisor.start_link(__MODULE__,
      %Cortex{
        sensors: sensors,
        neurons: neurons,
        actuators: actuators
      })
  end

  def init(cortex) do
    get_neuron_process = fn {_layer, neuron_struct} ->
      worker(Neuron, %Neuron{
            activation_function: neuron_struct.activation_function
             })
    end
    get_sensor_process = fn sensor_struct ->
      worker(Sensor, %Sensor{
            sync_function: sensor_struct.sync_function
             })
    end
    sensor_processes =
      Enum.each(cortex.sensors, get_sensor_process)
    get_actuator_process = fn actuator_struct ->
      worker(Actuator, %Actuator{
            actuator_function: actuator_struct.actuator_function
             })
    end
    actuator_processes =
      Enum.each(cortex.actuators, get_actuator_process)
    neuron_processes =
      Enum.map(cortex.neurons, get_neuron_process)
    children = sensor_processes ++ neuron_processes ++ actuator_processes
    supervise(children, strategy: :one_for_all)
  end
end
