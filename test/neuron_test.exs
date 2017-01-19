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
    weight = 2.3
    inbound_connections_with_new_inbound = Neuron.add_inbound_connection(empty_inbound_connections, from_node_pid, weight)

    connections_from_node_pid = Map.get(inbound_connections_with_new_inbound, from_node_pid)

    assert Enum.count(connections_from_node_pid) == 1

    connection_from_node_pid = List.first(connections_from_node_pid)
    assert connection_from_node_pid.connection_id == 1
    assert connection_from_node_pid.weight == weight
  end

  test "add_outbound_connection should add an outbound connection" do
    outbound_connections = []
    to_node_pid = 3
    updated_outbound_connections = Neuron.add_outbound_connection(outbound_connections, to_node_pid)

    assert Enum.count(updated_outbound_connections) == 1

    [outbound_connection_to_pid] = updated_outbound_connections
    assert outbound_connection_to_pid == to_node_pid
  end

  test ":add_outbound_connection message should return :ok if successful" do
    {:ok, neuron_pid} = GenServer.start_link(Neuron, %Neuron{})
    to_node_pid = 0
    returned_atom = GenServer.call(neuron_pid, {:add_outbound_connection, to_node_pid})
    assert returned_atom == :ok
  end

  test ":add_inbound_connection message should return :ok if successful" do
    {:ok, neuron_pid} = GenServer.start_link(Neuron, %Neuron{})
    from_node_pid = 0
    weight = 0.0
    returned_atom = GenServer.call(neuron_pid, {:add_inbound_connection, {from_node_pid, weight}})
    assert returned_atom == :ok
  end
end
