defmodule NeuralNode do

  @type node_id :: integer
  @type connection_id :: integer
  @type weight :: float
  @type inbound_connection :: {connection_id, weight}
  @type connections_from_node :: [inbound_connection]
  @type inbound_connections :: [{node_id, connections_from_node}]
  @type output_value :: float
  @type barrier :: [{{node_id, connection_id}, output_value}]

  #TODO refactor this to return {:ok, {connection_id, inbound_connections}}
  @spec add_inbound_connection(inbound_connections, node_id, weight) :: {:ok, {inbound_connections, connection_id}}
  def add_inbound_connection(inbound_connections, from_node_pid, weight) do
    connections_from_node_pid = Map.get(inbound_connections, from_node_pid, Map.new())
    new_connection_id = Enum.count(connections_from_node_pid) + 1
    updated_connections_from_node_pid =
      Map.put(connections_from_node_pid, new_connection_id, weight)
    updated_inbound_connections =
      Map.put(inbound_connections, from_node_pid, updated_connections_from_node_pid)
    {:ok, {updated_inbound_connections, new_connection_id}}
  end

  @spec add_inbound_connection(node_id, weight) :: {:ok, {inbound_connections, connection_id}}
  def add_inbound_connection(from_node_pid, weight) do
    add_inbound_connection(Map.new(), from_node_pid, weight)
  end

  @spec is_barrier_full?(barrier, inbound_connections) :: boolean
  def is_barrier_full?(barrier, inbound_connections) do
    connection_is_in_barrier? =
      (fn {from_node_id, connections_from_node} ->
        find_connection_in_barrier =
          (fn {connection_id, _weight} ->
            Map.has_key?(barrier, {from_node_id, connection_id})
          end)
        Enum.all?(connections_from_node, find_connection_in_barrier)
      end)
    Enum.all?(inbound_connections, connection_is_in_barrier?)
  end

  @spec remove_inbound_connection(inbound_connections, node_id, connection_id) :: {:ok, inbound_connections}
  def remove_inbound_connection(inbound_connections, from_node_id, connection_id) do
    connections_from_node_pid = Map.get(inbound_connections, from_node_id)
    updated_connections_from_node_pid =
      Map.delete(connections_from_node_pid, connection_id)

    inbound_connections =
      case Enum.count(updated_connections_from_node_pid) == 0 do
        true ->
          Map.delete(inbound_connections, from_node_id)
        false ->
          Map.put(inbound_connections, from_node_id, updated_connections_from_node_pid)
      end
    {:ok, inbound_connections}
  end

end
