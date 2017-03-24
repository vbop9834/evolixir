defmodule NodeTestHelper do
  use GenServer
  defstruct received_synapses: {},
    was_activated: false

  def start_link(name) do
    GenServer.start_link(__MODULE__, %NodeTestHelper{}, name: name)
  end

  @spec start_link() :: {:ok, pid}
  def start_link() do
    GenServer.start_link(__MODULE__, %NodeTestHelper{})
  end

  def handle_cast({:receive_synapse, synapse}, state) do
    updated_received_synapses = Tuple.append(state.received_synapses, synapse)
    updated_state = %NodeTestHelper{state | received_synapses: updated_received_synapses}
    {:noreply, updated_state}
  end

  def handle_call({:receive_blank_synapse, synapse}, _from, state) do
    updated_received_synapses = Tuple.append(state.received_synapses, synapse)
    updated_state = %NodeTestHelper{state | received_synapses: updated_received_synapses}
    {:reply, :ok, updated_state}
  end

  def handle_call({:activate, value}, _from, state) do
    updated_state = %NodeTestHelper{state |
                                    was_activated: {true, value}
                                   }
    {:reply, :ok, updated_state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end

defmodule DataGenerator do
  use GenServer

  def pop_data([data | rest_of_the_data]) do
    next_data = rest_of_the_data ++ data
    {data, next_data}
  end

  def handle_call(:pop, _from, state) do
    {return_data, updated_data} = pop_data(state)
    {:reply, return_data, updated_data}
  end
end

ExUnit.start()
