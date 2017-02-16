defmodule NodeIdGenerator do
  use GenServer
  def start_link(highest_node_id) do
    GenServer.start_link(NodeIdGenerator, highest_node_id+1)
  end

  def get_node_id(gen_pid) do
    GenServer.call(gen_pid, :get_node_id)
  end

  def handle_call(:get_node_id, _from, highest_node_id) do
    {:reply, highest_node_id, highest_node_id+1}
  end
end
