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
    connections_from_node_one = [fake_inbound_connection]
    inbound_connections =
      %{
        1 => connections_from_node_one
      }
    barrier =
      %{
        1 => %Synapse{}
      }
    barrier_is_full =
      Neuron.is_barrier_full?(barrier, inbound_connections)

    assert barrier_is_full == true
  end

  test "is_barrier_full? Should return true if barrier is not full" do
    fake_inbound_connection =
      %InboundNeuronConnection{connection_id: 1}
    fake_inbound_connection_two =
      %InboundNeuronConnection{connection_id: 2}
    connections_from_node_one =
      [
        fake_inbound_connection,
        fake_inbound_connection_two
      ]
    inbound_connections =
      %{
        1 => connections_from_node_one
      }
    barrier =
      %{
        1 => %Synapse{}
      }
    barrier_is_full =
      Neuron.is_barrier_full?(barrier, inbound_connections)

    assert barrier_is_full == false
  end

  test "apply_weight_to_syntax should multiply the weight by the synapse value and return an updated weighted synapse" do
    synapse = %Synapse{value: 1.0}
    inbound_connection_weight = 5.0
    weighted_synapse = Neuron.apply_weight_to_synapse(synapse, inbound_connection_weight)
    assert weighted_synapse.value == 5.0
  end

  test "add_inbound_connections should add the supplied pid and weight as an inbound connection" do
    empty_inbound_connections = Map.new()
    from_node_pid = 5
    new_connection_id = 1
    weight = 2.3
    inbound_connections_with_new_inbound = Neuron.add_inbound_connection(empty_inbound_connections, from_node_pid, new_connection_id, weight)

    connections_from_node_pid = Map.get(inbound_connections_with_new_inbound, from_node_pid)

    assert Enum.count(connections_from_node_pid) == 1

    connection_from_node_pid = List.first(connections_from_node_pid)
    assert connection_from_node_pid.connection_id == new_connection_id
    assert connection_from_node_pid.weight == weight
  end
end
