defmodule MutationProperties do
  defstruct sensors: [],
    neurons: Map.new(),
    actuators: [],
    activation_functions: Map.new(),
    mutation: nil
end
defmodule Mutations do

  defp add_bias(neurons) do
    update_bias = fn neuron_struct ->
      case neuron_struct.bias do
        nil ->
          new_bias = :random.uniform()
          %{neuron_struct | bias: new_bias}
        _x -> :bias_already_exists
      end
    end
    {random_layer, random_structs} = Enum.random(neurons)
    {random_neuron_id, random_neuron} = Enum.random(random_structs)
    maybe_updated_neuron = update_bias.(random_neuron)
    case maybe_updated_neuron do
      :bias_already_exists -> :bias_already_exists
      updated_neuron ->
        updated_layer_neurons =
          Map.put(random_structs, random_neuron_id, updated_neuron)
        Map.put(neurons, random_layer, updated_layer_neurons)
    end
  end

  defp mutate_activation_function(neurons, activation_functions) do
    {random_layer, random_structs} = Enum.random(neurons)
    {random_neuron_id, random_neuron} = Enum.random(random_structs)
    activation_function_with_id = Enum.random(activation_functions)
    updated_neuron = %Neuron{random_neuron |
                             activation_function: activation_function_with_id
                            }
    updated_layer_neurons =
      Map.put(random_structs, random_neuron_id, updated_neuron)
    Map.put(neurons, random_layer, updated_layer_neurons)
  end

  def mutate(%MutationProperties{
        mutation: :add_bias,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators
             }) do
    case add_bias(neurons) do
      :bias_already_exists -> :mutation_did_not_occur
      updated_neurons -> {sensors, updated_neurons, actuators}
    end
  end

  def mutate(%MutationProperties{
        mutation: :mutate_activation_function,
        sensors: sensors,
        neurons: neurons,
        actuators: actuators,
        activation_functions: activation_functions
             }) do
    updated_neurons = mutate_activation_function(neurons, activation_functions)
    {sensors, updated_neurons, actuators}
  end

end
