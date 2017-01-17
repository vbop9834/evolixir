defmodule Evolixir.NeuronTest do
  use ExUnit.Case
  doctest Neuron

  test "Neuron should be able to receive the async message receive_synapse" do
    {:ok, pid} = GenServer.start_link(Neuron, [])
    synapse = %{value: 0}
    GenServer.cast(pid, {:receive_synapse, synapse})
  end
end
