defmodule Evolixir.ActuatorTest do
  use ExUnit.Case
  doctest Actuator

  test "calculate_output_value should sum barrier" do
    barrier = %{
      {1, 4} => %Synapse{value: 4},
      {5, 2} => %Synapse{value: 1},
      {6, 3} => %Synapse{value: 1},
    }
    output_value = Actuator.calculate_output_value(barrier)
    assert output_value == 6
  end

  test ":add_inbound_connection should return connection id" do
    {:ok, actuator_pid} = GenServer.start_link(Actuator, %Actuator{})
    fake_node_pid = 4
    {:ok, connection_id} = GenServer.call(actuator_pid, {:add_inbound_connection, fake_node_pid})
    assert connection_id == 1
  end

  test ":add_inbound_connection should return new connection id" do
    {:ok, actuator_pid} = GenServer.start_link(Actuator, %Actuator{})
    fake_node_pid = 4
    {:ok, connection_id} = GenServer.call(actuator_pid, {:add_inbound_connection, fake_node_pid})
    {:ok, connection_id_two} = GenServer.call(actuator_pid, {:add_inbound_connection, fake_node_pid})
    assert connection_id == 1
    assert connection_id_two == 2
  end

  test ":receive_synapse should activate Actuator if barrier is full" do
    {:ok, actuator_test_helper_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})

    activate_function =
    fn output_value ->
      :ok = GenServer.call(actuator_test_helper_pid, {:activate, output_value})
    end

    {:ok, actuator_pid} = GenServer.start_link(Actuator, %Actuator{activate_function: activate_function})

    fake_node_pid = 9
    {:ok, connection_id} = GenServer.call(actuator_pid, {:add_inbound_connection, fake_node_pid})

    artificial_synapse = %Synapse{
      connection_id: connection_id,
      from_node_id: fake_node_pid,
      value: 1.5
    }
    GenServer.cast(actuator_pid, {:receive_synapse, artificial_synapse})

    :timer.sleep(5)
    updated_test_state = GenServer.call(actuator_test_helper_pid, :get_state)

    {true, activated_value} = updated_test_state.was_activated
    assert activated_value == artificial_synapse.value
  end

end
