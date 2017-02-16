defmodule HyperbolicTimeChamber do
  use GenServer
  defstruct fitness_function: nil,
    select_fit_population_function: nil,
    starting_generation_records: Map.new(),
    actuator_sources: Map.new(),
    sync_sources: Map.new(),
    activation_functions: Map.new(),
    possible_mutations: [],
    minds_per_generation: 5

  defp get_sync_function_from_source(sync_sources, cortex_id, sync_function) do
    sync_function_id =
      case sync_function do
        {sync_function_id, _sync_function} -> sync_function_id
        sync_function_id -> sync_function_id
      end
    sync_function_source = Map.get(sync_sources, sync_function_id)
    {sync_function_id, sync_function_source.(cortex_id)}
  end

  defp get_actuator_function_from_source(actuator_sources, cortex_id, actuator_function) do
    actuator_function_id =
      case actuator_function do
        {actuator_function_id, _actuator_function_id} -> actuator_function_id
        actuator_function_id -> actuator_function_id
      end
    actuator_source = Map.get(actuator_sources, actuator_function_id)
    {actuator_function_id, actuator_source.(cortex_id)}
  end

  defp hook_sensor_up_to_source(sync_sources, cortex_id, {sensor_id, sensor}) do
    sync_function = get_sync_function_from_source(sync_sources, cortex_id, sensor.sync_function)
    {sensor_id, %Sensor{sensor |
            sync_function: sync_function
    }}
  end

  defp hook_sensors_up_to_source(sync_sources, cortex_id, sensors) do
    Enum.map(sensors, &hook_sensor_up_to_source(sync_sources, cortex_id, &1))
  end

  defp hook_actuator_up_to_source(actuator_sources, cortex_id, {actuator_id, actuator}) do
    actuator_function = get_actuator_function_from_source(actuator_sources, cortex_id, actuator.actuator_function)
    {actuator_id, %Actuator{actuator |
                            actuator_function: actuator_function
                           }}
  end

  defp hook_actuators_up_to_source(actuator_sources, cortex_id, actuators) do
    Enum.map(actuators, &hook_actuator_up_to_source(actuator_sources, cortex_id, &1))
  end

  def create_brain(registry_name, actuator_sources, sync_sources, {cortex_id, {sensors, neurons, actuators}}) do
    sensors = hook_sensors_up_to_source(sync_sources, cortex_id, sensors)
    actuators = hook_actuators_up_to_source(actuator_sources, cortex_id, actuators)
    cortex = Cortex.start_link(registry_name, cortex_id, sensors, neurons, actuators)
    {cortex_id, cortex}
  end

  defp process_generation_evolution(maximum_number_per_generation, _mutation_properties, _possible_mutations, [], mutated_generation) do
    case Enum.count(mutated_generation) >= maximum_number_per_generation do
      true ->
        {:generation_complete, mutated_generation}
      false ->
        {:generation_incomplete, mutated_generation}
    end
  end

  defp process_generation_evolution(maximum_number_per_generation, mutation_properties, possible_mutations, [{_cortex_id, {sensors, neurons, actuators}} | remaining_generation], mutated_generation) do
    mutation_properties = %MutationProperties{mutation_properties |
      sensors: sensors,
      neurons: neurons,
      actuators: actuators
    }
    mutated_neural_network = Mutations.mutate_neural_network(possible_mutations, mutation_properties)
    new_cortex_id = Enum.count(mutated_generation) + 1
    updated_mutated_generation = Map.put(mutated_generation, new_cortex_id, mutated_neural_network)
    case Enum.count(updated_mutated_generation) >= maximum_number_per_generation do
      true ->
        {:generation_complete, updated_mutated_generation}
      false ->
        process_generation_evolution(maximum_number_per_generation, mutation_properties, possible_mutations, remaining_generation, updated_mutated_generation)
    end
  end

  defp evolve_generation(_maximum_number_per_generation, _mutation_properties, _possible_mutations, _generation, {:generation_complete, mutated_generation}) do
    mutated_generation
  end

  defp evolve_generation(maximum_number_per_generation, mutation_properties, possible_mutations, generation, {:generation_incomplete, mutated_generation}) do
    updated_mutated_generation = process_generation_evolution(maximum_number_per_generation, mutation_properties, possible_mutations, generation, mutated_generation)
    evolve_generation(maximum_number_per_generation, mutation_properties, possible_mutations, generation, updated_mutated_generation)
  end

  defp evolve_generation(maximum_number_per_generation, activation_functions, sync_sources, actuator_sources, possible_mutations, generation) do
    sync_functions = Map.keys(sync_sources)
    actuator_functions = Map.keys(actuator_sources)
    mutation_properties = %MutationProperties{
      activation_functions: activation_functions,
      sync_functions: sync_functions,
      actuator_functions: actuator_functions
    }
    evolve_generation(maximum_number_per_generation, mutation_properties, possible_mutations, Map.to_list(generation), {:generation_incomplete, generation})
  end

  def evolve(%HyperbolicTimeChamber{
        actuator_sources: actuator_sources,
        sync_sources: sync_sources,
        activation_functions: activation_functions,
        minds_per_generation: minds_per_generation,
        possible_mutations: possible_mutations,
        select_fit_population_function: select_fit_population_function
             }, scored_generation_records) do
    fit_generation = select_fit_population_function.(scored_generation_records)
    new_generation = evolve_generation(minds_per_generation, activation_functions, sync_sources, actuator_sources, possible_mutations, fit_generation)
    new_generation
  end

  defp get_new_generation_from_scored_records([], new_generation) do
    new_generation
  end

  defp get_new_generation_from_scored_records([{_score, cortex_id, neural_network} | remaining_scored_records], new_generation) do
    new_generation = Map.put(new_generation, cortex_id, neural_network)
    get_new_generation_from_scored_records(remaining_scored_records, new_generation)
  end

  defp get_new_generation_from_scored_records(scored_generation_records) do
    get_new_generation_from_scored_records(scored_generation_records, Map.new())
  end

  def get_select_fit_population_function(percent_of_generation_to_keep) do
    decimal_percent = percent_of_generation_to_keep / 100.0
    fn scored_generation_records ->
      number_of_records_to_keep =
        Enum.count(scored_generation_records) * decimal_percent
        |> round
      sorted_records = scored_generation_records |> Enum.sort
      new_generation =
        Enum.take(sorted_records, number_of_records_to_keep)
        |> get_new_generation_from_scored_records
      new_generation
    end
  end

end
