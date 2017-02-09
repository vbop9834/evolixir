defmodule Evolixir.NeuralNodeTest do
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
      NeuralNode.is_barrier_full?(barrier, inbound_connections)

    assert barrier_is_full == true
  end

  test "is_barrier_full? Should return true if barrier is full with two nodes" do
    connection_id_node_one = 9
    connection_id_node_two = 4
    weight = 2.0
    connections_from_node_one = %{
      connection_id_node_one => weight
    }
    connections_from_node_two = %{
      connection_id_node_two => weight
    }
    from_node_id = 1
    from_node_two_id = 5
    inbound_connections =
      %{
        from_node_id => connections_from_node_one,
        from_node_two_id => connections_from_node_two
      }

    barrier =
      %{
        {from_node_id, connection_id_node_one} => %Synapse{},
        {from_node_two_id, connection_id_node_two} => %Synapse{}
      }
    barrier_is_full =
      NeuralNode.is_barrier_full?(barrier, inbound_connections)

    assert barrier_is_full == true
  end

  test "is_barrier_full? Should return false if barrier is not full" do
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
      NeuralNode.is_barrier_full?(barrier, inbound_connections)

    assert barrier_is_full == false
  end

  test "is_barrier_full? Should return false if barrier is not full with two nodes" do
    fake_inbound_connection_id = 1
    fake_inbound_connection_id_two = 2
    connections_from_node_one =
      %{
        fake_inbound_connection_id => 0.0
      }
    connections_from_node_two = %{
      fake_inbound_connection_id_two => 1.0
    }
    inbound_connections =
      %{
        1 => connections_from_node_one,
        2 => connections_from_node_two
      }
    barrier =
      %{
        1 => %Synapse{}
      }
    barrier_is_full =
      NeuralNode.is_barrier_full?(barrier, inbound_connections)

    assert barrier_is_full == false
  end

  test "add_inbound_connections should add the supplied pid and weight as an inbound connection" do
    empty_inbound_connections = Map.new()
    from_node_pid = 5
    weight = 2.3
    {inbound_connections_with_new_inbound, new_connection_id} = NeuralNode.add_inbound_connection(empty_inbound_connections, from_node_pid, weight)

    connections_from_node_pid = Map.get(inbound_connections_with_new_inbound, from_node_pid)

    assert new_connection_id == 1
    assert Enum.count(connections_from_node_pid) == 1
    assert Map.has_key?(connections_from_node_pid, new_connection_id) == true

    connection_weight = Map.get(connections_from_node_pid, new_connection_id)
    assert connection_weight == weight
  end

end
