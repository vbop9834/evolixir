defmodule NeuronTestHelper do
  use GenServer
  defstruct times_fired: 0

  def init(args) do
    {:ok, args}
  end

  def handle_call(:get_times_fired, _from, state) do
    {:reply, state.times_fired}
  end

  def handle_cast({:receive_synapse, synapse}, state) do
    updated_times_fired = state.times_fired+1
    updated_state =
      %{ state |
         times_fired: updated_times_fired
       }
    {:noreply, updated_state}
  end

end

defmodule Evolixir.NeuronTest do
  use ExUnit.Case
  doctest Neuron

  test "is_barrier_full? Should return true if barrier is full" do
    fake_inbound_connection =
      %InboundNeuronConnection{connection_id: 1}
    connections_from_node_one =
      Enum.map([1], fn(_) -> fake_inbound_connection end)
    inbound_connections =
      %{
        1 => connections_from_node_one
      }
    barrier =
      %{
        3 => %Synapse{},
        1 => %Synapse{},
        2 => %Synapse{}
      }
    barrier_is_full =
      Neuron.is_barrier_full?(barrier, inbound_connections)

    assert barrier_is_full == true
  end

  test "apply_weight_to_syntax should multiply the weight by the synapse value and return an updated weighted synapse" do
    synapse = %Synapse{value: 1.0}
    inbound_connection_weight = 5.0
    weighted_synapse = Neuron.apply_weight_to_synapse(synapse, inbound_connection_weight)
    assert weighted_synapse.value == 5.0
  end
end
