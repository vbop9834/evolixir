defmodule Evolixir.NodeTest do
  use ExUnit.Case
  doctest Node

  test "is_barrier_full? Should return true if barrier is full" do
    connection_id = 9
    weight = 2.0
    connections_from_node_one = Map.put(Map.new(), connection_id, weight)
    from_node_id = 1
    inbound_connections =
      %{
        from_node_id => connections_from_node_one
      }
    barrier =
      %{
        {from_node_id, connection_id} => %Synapse{}
      }
    barrier_is_full =
      Node.is_barrier_full?(barrier, inbound_connections)

    assert barrier_is_full == true
  end

  test "is_barrier_full? Should return true if barrier is not full" do
    fake_inbound_connection_id = 1
    fake_inbound_connection_id_two = 2
    connections_from_node_one =
      %{
        fake_inbound_connection_id => 0.0,
        fake_inbound_connection_id_two => 0.2
      }
    inbound_connections =
      %{
        1 => connections_from_node_one
      }
    barrier =
      %{
        1 => %Synapse{}
      }
    barrier_is_full =
      Node.is_barrier_full?(barrier, inbound_connections)

    assert barrier_is_full == false
  end

  test "add_inbound_connections should add the supplied pid and weight as an inbound connection" do
    empty_inbound_connections = Map.new()
    from_node_pid = 5
    weight = 2.3
    {inbound_connections_with_new_inbound, new_connection_id} = Node.add_inbound_connection(empty_inbound_connections, from_node_pid, weight)

    connections_from_node_pid = Map.get(inbound_connections_with_new_inbound, from_node_pid)

    assert new_connection_id == 1
    assert Enum.count(connections_from_node_pid) == 1
    assert Map.has_key?(connections_from_node_pid, new_connection_id) == true

    connection_weight = Map.get(connections_from_node_pid, new_connection_id)
    assert connection_weight == weight
  end

  test "add_outbound_connection should add an outbound connection" do
    outbound_connections = []
    to_node_pid = 3
    connection_id = 1
    updated_outbound_connections = Node.add_outbound_connection(outbound_connections, to_node_pid, connection_id)

    assert Enum.count(updated_outbound_connections) == 1

    [{outbound_connection_to_pid, outbound_connection_id}] = updated_outbound_connections
    assert outbound_connection_to_pid == to_node_pid
    assert connection_id == outbound_connection_id
  end

end
