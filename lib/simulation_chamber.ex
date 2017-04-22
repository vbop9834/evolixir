defmodule SimulationChamber do
  require Logger
  defstruct chamber_name: :simulation_chamber,
    select_fit_population_function: nil,
    starting_generation_records: Map.new(),
    activation_functions: Map.new(),
    actuator_sources: Map.new(),
    sync_sources: Map.new(),
    possible_mutations: Mutations.default_mutation_sequence,
    minds_per_generation: 5,
    fitness_function: nil,
    max_attempts_to_perturb: nil,
    end_of_generation_function: nil,
    learning_function: nil,
    think_timeout: 5000,
    lifetime_timeout: 60000,
    think_cycles_per_lifetime: 5

  @type chamber_name :: atom
  @type simulation_chamber_properties :: SimulationChamber
  @type think_timeout :: integer
  @type think_cycles :: integer

  @type sync_source_id :: integer
  @type sync_source :: (Cortex.cortex_id -> Sensor.sync_function)
  @type sync_sources :: [{sync_source_id, sync_source}]

  @type score :: integer
  @type scores :: [score]
  @type fitness_function :: (Cortex.cortex_id -> score)
  @type generation_record :: {Cortex.cortex_id, Cortex.neural_network}
  @type generation_records :: [generation_record]
  @type scored_generation_record :: {score, Cortex.cortex_id, Cortex.neural_network}
  @type scored_generation_records :: [scored_generation_record]
  @type generations_to_simulate :: integer

  @type end_of_generation_function :: (scored_generation_records -> :ok)

  @spec think(chamber_name, think_timeout, Cortex.cortex_id) :: :ok
  defp think(chamber_name, think_timeout, cortex_id) do
    try do
      :ok = Cortex.think(think_timeout, chamber_name, cortex_id)
      :ok
    catch
      :exit, _ -> :error
    rescue
      _e -> :error
    end
  end

  @spec process_think_cycles(chamber_name, think_timeout, fitness_function, Cortex.cortex_id, think_cycles, think_cycles, scores) :: {:ok, score}
  defp process_think_cycles(chamber_name, _think_timeout, _fitness_function, cortex_id, maximum_think_cycles, current_cycle_number, scores)
    when maximum_think_cycles <= current_cycle_number do
    #Terminate Brain
    :ok = Cortex.kill_cortex(chamber_name, cortex_id)
    #Sum the scores from think cycles
    total_score = (scores |> Enum.sum)
    {:ok, total_score}
  end

  @spec process_think_cycles(chamber_name, think_timeout, fitness_function, Cortex.cortex_id, think_cycles, think_cycles, scores) :: {:ok, score}
  defp process_think_cycles(chamber_name, think_timeout, fitness_function, cortex_id, maximum_think_cycles, current_cycle_number, scores)
    when maximum_think_cycles > current_cycle_number do
    #Stimulate the cortex to process a think cycle
    case think(chamber_name, think_timeout, cortex_id) do
      :ok ->
        #Score the result of the think cycle
        case fitness_function.(cortex_id) do
          {:continue_think_cycle, score} ->
            #Add score to scores
            scores = scores ++ [score]
            #Increment cycle number
            current_cycle_number = current_cycle_number + 1
            #Recurse
            process_think_cycles(chamber_name, think_timeout, fitness_function, cortex_id, maximum_think_cycles, current_cycle_number, scores)
          {:end_think_cycle, score} ->
            #Terminate Brain
            :ok = Cortex.kill_cortex(chamber_name, cortex_id)
            #Think cycles terminated by fitness function
            #Sum the scores from think cycles
            total_score =
              case scores do
                [] -> -500
                scores -> (scores |> Enum.sum) + score
              end
            {:ok, total_score}
        end
      :error ->
        :ok = Cortex.kill_cortex(chamber_name, cortex_id)
        #Think cycles terminated by fitness function
        #Sum the scores from think cycles
        total_score =
          case scores do
            [] -> -500
            scores -> (scores |> Enum.sum)
          end
        {:ok, total_score}
    end
  end

  @spec simulate_brain(simulation_chamber_properties, generation_record) :: scored_generation_record
  def simulate_brain(simulation_chamber_properties, {cortex_id, neural_network}) do
    #Hook the network into respective sources
    #Start the neural network
    :ok = HyperbolicTimeChamber.create_brain(simulation_chamber_properties.chamber_name, simulation_chamber_properties.sync_sources, simulation_chamber_properties.actuator_sources, {cortex_id, neural_network})
    #Process think cycles
    {:ok, score} = process_think_cycles(simulation_chamber_properties.chamber_name, simulation_chamber_properties.think_timeout, simulation_chamber_properties.fitness_function, cortex_id, simulation_chamber_properties.think_cycles_per_lifetime, 0, [])
    {:ok, {score, cortex_id, neural_network}}
  end

  @spec process_generation_simulation(simulation_chamber_properties, generation_records) :: {:ok, scored_generation_records}
  defp process_generation_simulation(simulation_chamber_properties, generation_records) do
    #Create async tasks and await for processing each brain's think cycles and scoring the brain
    create_brain_task = fn {cortex_id, neural_network} ->
      Task.async(fn ->
        try do
          {:ok, scored_generation_record} = simulate_brain(simulation_chamber_properties, {cortex_id, neural_network})
          scored_generation_record
        catch
          :exit, _ -> {-500, cortex_id, neural_network}
        rescue
          _e -> {-500, cortex_id, neural_network}
        end
      end)
    end
    timeout = simulation_chamber_properties.lifetime_timeout
    scored_generation_records =
      Enum.map(generation_records, create_brain_task)
      |> Enum.map(fn task -> Task.await(task, timeout) end)
    {:ok, scored_generation_records}
  end

  @spec evolve_generation(simulation_chamber_properties, scored_generation_records) :: {:ok, generation_records}
  defp evolve_generation(%SimulationChamber{
         actuator_sources: actuator_sources,
         sync_sources: sync_sources,
         activation_functions: activation_functions,
         minds_per_generation: minds_per_generation,
         possible_mutations: possible_mutations,
         learning_function: learning_function,
         select_fit_population_function: select_fit_population_function
                         }, scored_generation_records) do
    Logger.info "Selecting fit population"
    fit_generation = select_fit_population_function.(scored_generation_records)
    new_generation = HyperbolicTimeChamber.evolve_generation(minds_per_generation, activation_functions, sync_sources, actuator_sources, learning_function, possible_mutations, fit_generation)
    {:ok, new_generation}
  end

  @spec process_end_of_generation_function(nil, scored_generation_records) :: :ok
  defp process_end_of_generation_function(nil, _scored_generation_records) do
    :ok
  end

  @spec process_end_of_generation_function(end_of_generation_function, scored_generation_records) :: :ok
  defp process_end_of_generation_function(end_of_generation_function, scored_generation_records) do
    :ok = end_of_generation_function.(scored_generation_records)
    :ok
  end

  defp kill_registry(chamber_name) do
    :ok = GenServer.stop(chamber_name)
    :ok
  end

  @spec simulate(simulation_chamber_properties, generations_to_simulate, scored_generation_records, integer) :: {:ok, scored_generation_records}
  def simulate(simulation_chamber_properties, generations_to_simulate, scored_generation_records, generations_simulated)
    when generations_to_simulate <= generations_simulated do
    #Generation limit reached
    #Terminate registry
    :ok = kill_registry(simulation_chamber_properties.chamber_name)
    #return scored records
    {:ok, scored_generation_records}
  end

  @spec simulate(simulation_chamber_properties, generations_to_simulate, scored_generation_records, integer) :: {:ok, scored_generation_records}
  def simulate(simulation_chamber_properties, generations_to_simulate, scored_generation_records, generations_simulated)
    when generations_to_simulate > generations_simulated do
    #Evolve generation
    {:ok, generation_records} = evolve_generation(simulation_chamber_properties, scored_generation_records)
    #Process generation simulation to acquire scores
    {:ok, scored_generation_records} = process_generation_simulation(simulation_chamber_properties, generation_records)
    #Call configurable end of generation function hook
    :ok = process_end_of_generation_function(simulation_chamber_properties.end_of_generation_function, scored_generation_records)
    #Increment generations simulated
    generations_simulated = generations_simulated + 1
    #Recurse
    simulate(simulation_chamber_properties, generations_to_simulate, scored_generation_records, generations_simulated)
  end

  @spec simulate(simulation_chamber_properties, generations_to_simulate) :: {:ok, scored_generation_records}
  def simulate(simulation_chamber_properties, generations_to_simulate) do
    #Start chamber registry
    {:ok, _registry_pid} = Registry.start_link(:unique, simulation_chamber_properties.chamber_name)
    #Starting Generation Records
    generation_records = simulation_chamber_properties.starting_generation_records
    #Process Starting Generation Records
    {:ok, scored_generation_records} = process_generation_simulation(simulation_chamber_properties, generation_records)
    #Increment Generations Simulated
    generations_simulated = 1
    #Recurse
    simulate(simulation_chamber_properties, generations_to_simulate, scored_generation_records, generations_simulated)
  end
end
