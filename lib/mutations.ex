defmodule Mutations do

  def mutate(
    %{
      sensors: sensors,
      neurons: neurons,
      actuators: actuators,
      mutation: mutation,
      activation_functions: activation_functions
    }) do
    case mutation do
      :mutate_activation_function ->
        {random_layer, random_structs} = Enum.random(neurons)
        {random_neuron_id, random_neuron} = Enum.random(random_structs)
        activation_function_with_id = Enum.random(activation_functions)
        updated_neuron = %Neuron{random_neuron |
                                   activation_function: activation_function_with_id
                          }
        updated_layer_neurons =
          Map.put(random_structs, random_neuron_id, updated_neuron)
        updated_neurons =
          Map.put(neurons, random_layer, updated_layer_neurons)
        {sensors, updated_neurons, actuators}
    end
  end

end
