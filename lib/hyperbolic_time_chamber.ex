defmodule HyperbolicTimeChamberState do
  defstruct hyperbolic_time_chamber_properties: nil,
    active_cortex_id: nil,
    active_cortex_scores: [],
    active_cortex_records: nil,
    scored_generation_records: [],
    remaining_generation: [],
    chamber_registry_name: nil
end
defmodule HyperbolicTimeChamber do
  use GenServer
  require Logger
  defstruct fitness_function: nil,
    select_fit_population_function: nil,
    starting_generation_records: Map.new(),
    actuator_sources: Map.new(),
    sync_sources: Map.new(),
    activation_functions: Map.new(),
    possible_mutations: [],
    minds_per_generation: 5,
    fitness_function: nil,
    max_attempts_to_perturb: nil,
    end_of_generation_function: nil

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

  def hook_sensors_up_to_source(sync_sources, cortex_id, sensors) do
    Logger.info "Hooking sensors into sources"
    Enum.map(sensors, &hook_sensor_up_to_source(sync_sources, cortex_id, &1))
    |> Map.new
  end

  defp hook_actuator_up_to_source(actuator_sources, cortex_id, {actuator_id, actuator}) do
    actuator_function = get_actuator_function_from_source(actuator_sources, cortex_id, actuator.actuator_function)
    {actuator_id, %Actuator{actuator |
                            actuator_function: actuator_function
                           }}
  end

  def hook_actuators_up_to_source(actuator_sources, cortex_id, actuators) do
    Logger.info "Hooking actuators into sources"
    Enum.map(actuators, &hook_actuator_up_to_source(actuator_sources, cortex_id, &1))
    |> Map.new
  end

  defp create_brain(registry_name, sync_sources, actuator_sources, {cortex_id, {sensors, neurons, actuators}}) do
    Logger.info "Starting brain creation"
    sensors = hook_sensors_up_to_source(sync_sources, cortex_id, sensors)
    actuators = hook_actuators_up_to_source(actuator_sources, cortex_id, actuators)
    {:ok, _cortex_pid} = Cortex.start_link(registry_name, cortex_id, sensors, neurons, actuators)
    :ok = Cortex.reset_network(registry_name, cortex_id)
    :ok
  end

  defp process_generation_evolution(maximum_number_per_generation, _mutation_properties, _possible_mutations, [], mutated_generation) do
    case Enum.count(mutated_generation) >= maximum_number_per_generation do
      true ->
        Logger.info "Generation limit reached"
        {:generation_complete, mutated_generation}
      false ->
        {:generation_incomplete, mutated_generation}
    end
  end

  defp process_generation_evolution(maximum_number_per_generation, mutation_properties, possible_mutations, [{_cortex_id, {sensors, neurons, actuators}} | remaining_generation], mutated_generation) do
    case Enum.count(mutated_generation) >= maximum_number_per_generation do
      true ->
        Logger.info "Generation limit reached"
        {:generation_complete, mutated_generation}
      false ->
        mutation_properties = %MutationProperties{mutation_properties |
                                                  sensors: sensors,
                                                  neurons: neurons,
                                                  actuators: actuators
                                                 }
        mutated_neural_network = Mutations.mutate_neural_network(possible_mutations, mutation_properties)
        new_cortex_id = Enum.count(mutated_generation) + 1
        updated_mutated_generation = Map.put(mutated_generation, new_cortex_id, mutated_neural_network)
        process_generation_evolution(maximum_number_per_generation, mutation_properties, possible_mutations, remaining_generation, updated_mutated_generation)
    end
  end

  defp evolve_generation(_maximum_number_per_generation, _mutation_properties, _possible_mutations, _generation, {:generation_complete, mutated_generation}) do
    Logger.info "Generation evolution complete"
    mutated_generation
  end

  defp evolve_generation(maximum_number_per_generation, mutation_properties, possible_mutations, generation, {:generation_incomplete, mutated_generation}) do
    Logger.info "Generation evolution incomplete. Reiterating and mutating"
    updated_mutated_generation = process_generation_evolution(maximum_number_per_generation, mutation_properties, possible_mutations, generation, mutated_generation)
    evolve_generation(maximum_number_per_generation, mutation_properties, possible_mutations, generation, updated_mutated_generation)
  end

  defp evolve_generation(maximum_number_per_generation, activation_functions, sync_sources, actuator_sources, possible_mutations, generation) do
    Logger.info "Starting generation evolution"
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
    Logger.info "Selecting fit population"
    fit_generation = select_fit_population_function.(scored_generation_records)
    new_generation = evolve_generation(minds_per_generation, activation_functions, sync_sources, actuator_sources, possible_mutations, fit_generation)
    new_generation
  end

  defp get_new_generation_from_scored_records([], new_generation) do
    new_generation
  end

  defp get_new_generation_from_scored_records([{_score, cortex_id, neural_network} | remaining_scored_records], new_generation) do
    case cortex_id do
      {cortex_id, _perturb_id} ->
        new_generation = Map.put(new_generation, cortex_id, neural_network)
        get_new_generation_from_scored_records(remaining_scored_records, new_generation)
      cortex_id ->
        new_generation = Map.put(new_generation, cortex_id, neural_network)
        get_new_generation_from_scored_records(remaining_scored_records, new_generation)
    end
  end

  defp get_new_generation_from_scored_records(scored_generation_records) do
    get_new_generation_from_scored_records(scored_generation_records, Map.new())
  end

  defp distinct_scored_records_by_cortex_id([], distinct_records) do
    Logger.info "Filtering perturbed records by highest score complete"
    distinct_records
  end

  defp distinct_scored_records_by_cortex_id([{score, {cortex_id, _perturb_id}, perturbed_neural_network} | remaining_scores], distinct_records) do
    #TODO get returns a nil which introduces a possible bug
    #If the default score is higher than the actually scored brains
    #Then nil will be processed D:
    {current_score, neural_network} = Map.get(distinct_records, cortex_id, {-10000000, nil})
    updated_current_cortex_scores =
      case score > current_score do
        true ->
          {score, perturbed_neural_network}
        false ->
          {current_score, neural_network}
      end
    distinct_records = Map.put(distinct_records, cortex_id, updated_current_cortex_scores)
    distinct_scored_records_by_cortex_id(remaining_scores, distinct_records)
  end

  defp distinct_scored_records_by_cortex_id(_scored_records, _distinct_records) do
    Logger.info "Scored records were not perturbed"
    :did_not_perturb
  end

  def get_select_fit_population_function(percent_of_generation_to_keep) do
    decimal_percent = percent_of_generation_to_keep / 100.0
    fn scored_generation_records ->
      distinct_scored_generation_records = distinct_scored_records_by_cortex_id(scored_generation_records, Map.new())
      sorted_records =
        case distinct_scored_generation_records do
          :did_not_perturb ->
            scored_generation_records
            |> Enum.sort
            |> Enum.reverse
          distinct_scored_generation_records ->
            flatten_distinct_scores = fn {cortex_id, {score, neural_network}} ->
              {score, cortex_id, neural_network}
            end
            Enum.map(distinct_scored_generation_records, flatten_distinct_scores)
            |> Enum.sort
            |> Enum.reverse
        end
      number_of_records_to_keep =
        Enum.count(sorted_records) * decimal_percent
        |> round
      new_generation =
        Enum.take(sorted_records, number_of_records_to_keep)
        |> get_new_generation_from_scored_records
      new_generation
    end
  end

  defp get_new_active_cortex_from_perturbed_networks([]) do
    :perturb_is_complete
  end

  defp get_new_active_cortex_from_perturbed_networks([{perturb_id, {sensors, neurons, actuators}} | remaining_networks]) do
    {perturb_id, {sensors, neurons, actuators}, remaining_networks}
  end

  defp get_new_active_cortex(_sync_sources, _actuator_sources, _registry_name, {_, []}) do
    :generation_is_complete
  end

  defp get_new_active_cortex(sync_sources, actuator_sources, registry_name, {:did_not_perturb, [{new_cortex_id, {sensors, neurons, actuators}} | remaining_generation]}) do
    neural_network = {sensors, neurons, actuators}
    :ok = create_brain(registry_name, sync_sources, actuator_sources, {new_cortex_id, neural_network})
    {new_cortex_id, neural_network, {:did_not_perturb, remaining_generation}}
  end

  defp get_new_active_cortex(sync_sources, actuator_sources, registry_name, {:did_perturb, [{new_cortex_id, neural_networks} | remaining_generation]}) do
    Logger.info "Acquiring new active cortex"
    case get_new_active_cortex_from_perturbed_networks(neural_networks) do
      :perturb_is_complete ->
        Logger.info "Perturbing is completed for cortex"
        get_new_active_cortex(sync_sources, actuator_sources, registry_name, {:did_perturb, remaining_generation})
      {perturb_id, neural_network, remaining_perturbed_networks} ->
        Logger.info "Perturbing is incomplete. Creating perturbed network variant"
        :ok = create_brain(registry_name, sync_sources, actuator_sources, {{new_cortex_id, perturb_id}, neural_network})
        remaining_generation = [{new_cortex_id, remaining_perturbed_networks}] ++ remaining_generation
        {{new_cortex_id, perturb_id}, neural_network, {:did_perturb, remaining_generation}}
    end
  end

  def think_and_act(chamber_pid, think_timeout) do
    GenServer.call(chamber_pid, :think_and_act, think_timeout)
  end

  defp get_perturbed_networks([], _max_attempts_possible, perturbed_generation) do
    Map.to_list(perturbed_generation)
  end

  defp get_perturbed_networks([{cortex_id, neural_network} | remaining_generation], max_attempts_possible, perturbed_generation) do
    perturbed_neural_networks = StochasticHillClimber.perturb_weights_in_neural_network(neural_network, max_attempts_possible)
    perturbed_neural_networks_with_original_topology = [{0, neural_network}] ++ perturbed_neural_networks
    perturbed_generation = Map.put(perturbed_generation, cortex_id, perturbed_neural_networks_with_original_topology)
    get_perturbed_networks(remaining_generation, max_attempts_possible, perturbed_generation)
  end

  defp get_perturbed_networks(hyperbolic_time_chamber_properties, generation) do
    case hyperbolic_time_chamber_properties.max_attempts_to_perturb do
      nil ->
        Logger.info "Max_attempts_to_perturb is set to nil. skipping perturb"
        {:did_not_perturb, generation}
      max_attempts_possible ->
        Logger.info "Perturbing generation"
        perturbed_generation = get_perturbed_networks(generation, max_attempts_possible, Map.new())
        {:did_perturb, perturbed_generation}
      end
  end

  defp process_fitness_function_result({:end_think_cycle, score}, state) do
    Logger.info "Think cycle finished. Scoring and killing active cortex"
    final_score = Enum.sum(state.active_cortex_scores) + score
    Cortex.kill_cortex(state.chamber_registry_name, state.active_cortex_id)

    updated_scored_generation_records =
      state.scored_generation_records ++ [{final_score, state.active_cortex_id, state.active_cortex_records}]

    #TODO refactor this into multiple functions
    {new_active_cortex_id, active_cortex_records,
     updated_scored_generation_records, remaining_generation} =
      case get_new_active_cortex(state.hyperbolic_time_chamber_properties.sync_sources, state.hyperbolic_time_chamber_properties.actuator_sources, state.chamber_registry_name, state.remaining_generation) do
        {new_cortex_id, cortex_records, remaining_generation} ->
          {new_cortex_id, cortex_records, updated_scored_generation_records, remaining_generation}
        :generation_is_complete ->
          Logger.info "Generation is complete. Mutating new generation"
          #TODO review this to list operation
          case state.hyperbolic_time_chamber_properties.end_of_generation_function do
            nil -> ()
            end_of_generation_function -> end_of_generation_function.(updated_scored_generation_records)
          end
          mutated_generation =
            evolve(state.hyperbolic_time_chamber_properties, updated_scored_generation_records)
            |> Map.to_list
          perturbed_generation = get_perturbed_networks(state.hyperbolic_time_chamber_properties, mutated_generation)
          {new_cortex_id, cortex_records, remaining_generation} =
            get_new_active_cortex(state.hyperbolic_time_chamber_properties.sync_sources, state.hyperbolic_time_chamber_properties.actuator_sources, state.chamber_registry_name, perturbed_generation)
          empty_scored_records = []
          {new_cortex_id, cortex_records, empty_scored_records, remaining_generation}
      end

    %HyperbolicTimeChamberState{state |
                                active_cortex_id: new_active_cortex_id,
                                active_cortex_scores: [],
                                active_cortex_records: active_cortex_records,
                                scored_generation_records: updated_scored_generation_records,
                                remaining_generation: remaining_generation
    }
  end

  defp process_fitness_function_result({:continue_think_cycle, score}, state) do
    Logger.info "Continuing think cycle. Adding score to active cortex"
    updated_active_cortex_scores =
      state.active_cortex_scores ++ [score]
    %HyperbolicTimeChamberState{state |
                                active_cortex_scores: updated_active_cortex_scores
    }
  end

  def process_think_and_act(state) do
    Logger.info "Sending think message to active cortex"
    Cortex.think(state.chamber_registry_name, state.active_cortex_id)
    Logger.info "Sending active cortex through fitness function"
    fitness_function_result = state.hyperbolic_time_chamber_properties.fitness_function.(state.active_cortex_id)
    process_fitness_function_result(fitness_function_result, state)
  end

  def start_link(chamber_name, hyperbolic_time_chamber_properties) do
    Logger.info "Starting chamber registry"
    {:ok, _registry_pid} = Registry.start_link(:unique, chamber_name)
    perturbed_generation = get_perturbed_networks(hyperbolic_time_chamber_properties, Map.to_list(hyperbolic_time_chamber_properties.starting_generation_records))
    {new_cortex_id, cortex_records, remaining_generation} =
      get_new_active_cortex(hyperbolic_time_chamber_properties.sync_sources, hyperbolic_time_chamber_properties.actuator_sources, chamber_name, perturbed_generation)
    state = %HyperbolicTimeChamberState{
      active_cortex_id: new_cortex_id,
      active_cortex_records: cortex_records,
      hyperbolic_time_chamber_properties: hyperbolic_time_chamber_properties,
      remaining_generation: remaining_generation,
      chamber_registry_name: chamber_name
    }
    GenServer.start_link(__MODULE__, state)
  end

  def handle_call(:think_and_act, _from,  state) do
    Logger.info "Chamber received think and act message"
    updated_state =
      process_think_and_act(state)
    {:reply, :ok, updated_state}
  end

end
