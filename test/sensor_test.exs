defmodule Evolixir.SensorTest do
  use ExUnit.Case
  doctest Sensor

  test "add_outbound_connection should add outbound node pid and connection id to connections" do
    outbound_connections = []
    to_node_pid = 5
    connection_id = 2

    added_outbound_connections = Sensor.add_outbound_connection(outbound_connections, to_node_pid, connection_id)
    assert Enum.count(added_outbound_connections) == 1

    [{added_to_node_pid, added_connection_id}] = added_outbound_connections
    assert added_to_node_pid == to_node_pid
    assert added_connection_id == connection_id
  end

  test "send_synapse_to_outbound_connection should send a synapse to the supplied pid" do
    data = 0.38
    {:ok, to_node_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    connection_id = 5

    Sensor.send_synapse_to_outbound_connection(data, to_node_pid, connection_id)

    :timer.sleep(5)
    updated_test_state = GenServer.call(to_node_pid, :get_state)

    {received_synapse} = updated_test_state.received_synapses
    assert received_synapse.connection_id == connection_id
    assert_in_delta received_synapse.value, data, 0.001
    assert received_synapse.from_node_id == self()
  end

  test "process_sensor_data should process all of the outbound_connections" do
    sensor_data = [1, 2, 3]
    {:ok, to_node_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    connection_id_one = 8
    connection_id_two = 3
    connection_id_three = 6

    outbound_connections = [
      {to_node_pid, connection_id_one},
      {to_node_pid, connection_id_two},
      {to_node_pid, connection_id_three}
    ]
    Sensor.process_sensor_data(sensor_data, outbound_connections)

    :timer.sleep(5)
    updated_test_state = GenServer.call(to_node_pid, :get_state)

    [expected_data_one, expected_data_two, expected_data_three] = sensor_data
    {received_synapse_one, received_synapse_two, received_synapse_three} = updated_test_state.received_synapses

    assert received_synapse_one.connection_id == connection_id_one
    assert_in_delta received_synapse_one.value, expected_data_one, 0.001
    assert received_synapse_one.from_node_id == self()

    assert received_synapse_two.connection_id == connection_id_two
    assert_in_delta received_synapse_two.value, expected_data_two, 0.001
    assert received_synapse_two.from_node_id == self()

    assert received_synapse_three.connection_id == connection_id_three
    assert_in_delta received_synapse_three.value, expected_data_three, 0.001
    assert received_synapse_three.from_node_id == self()
  end

  test "process_sensor_data should send 0.0 when out of sensor_data" do
    sensor_data = [1]
    {:ok, to_node_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    connection_id_one = 8
    connection_id_two = 3
    connection_id_three = 6

    outbound_connections = [
      {to_node_pid, connection_id_one},
      {to_node_pid, connection_id_two},
      {to_node_pid, connection_id_three}
    ]
    Sensor.process_sensor_data(sensor_data, outbound_connections)

    :timer.sleep(5)
    updated_test_state = GenServer.call(to_node_pid, :get_state)

    [expected_data_one] = sensor_data
    {received_synapse_one, received_synapse_two, received_synapse_three} = updated_test_state.received_synapses

    assert received_synapse_one.connection_id == connection_id_one
    assert_in_delta received_synapse_one.value, expected_data_one, 0.001
    assert received_synapse_one.from_node_id == self()

    assert received_synapse_two.connection_id == connection_id_two
    assert_in_delta received_synapse_two.value, 0.0, 0.001
    assert received_synapse_two.from_node_id == self()

    assert received_synapse_three.connection_id == connection_id_three
    assert_in_delta received_synapse_three.value, 0.0, 0.001
    assert received_synapse_three.from_node_id == self()
  end

  test "synchronize should execute the sync_function and process the data" do
    sensor_data = [1, 2, 3]
    sync_function = fn () -> sensor_data end
    {:ok, to_node_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    connection_id_one = 8
    connection_id_two = 3
    connection_id_three = 6

    outbound_connections = [
      {to_node_pid, connection_id_one},
      {to_node_pid, connection_id_two},
      {to_node_pid, connection_id_three}
    ]
    Sensor.synchronize(sync_function, outbound_connections)

    :timer.sleep(5)
    updated_test_state = GenServer.call(to_node_pid, :get_state)

    [expected_data_one, expected_data_two, expected_data_three] = sensor_data
    {received_synapse_one, received_synapse_two, received_synapse_three} = updated_test_state.received_synapses

    assert received_synapse_one.connection_id == connection_id_one
    assert_in_delta received_synapse_one.value, expected_data_one, 0.001
    assert received_synapse_one.from_node_id == self()

    assert received_synapse_two.connection_id == connection_id_two
    assert_in_delta received_synapse_two.value, expected_data_two, 0.001
    assert received_synapse_two.from_node_id == self()

    assert received_synapse_three.connection_id == connection_id_three
    assert_in_delta received_synapse_three.value, expected_data_three, 0.001
    assert received_synapse_three.from_node_id == self()
  end

  test "synchronize should execute the sync_function and send 0.0 when no data is provided" do
    sensor_data = []
    sync_function = fn () -> sensor_data end
    {:ok, to_node_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    connection_id_one = 8
    connection_id_two = 3
    connection_id_three = 6

    outbound_connections = [
      {to_node_pid, connection_id_one},
      {to_node_pid, connection_id_two},
      {to_node_pid, connection_id_three}
    ]
    Sensor.synchronize(sync_function, outbound_connections)

    :timer.sleep(5)
    updated_test_state = GenServer.call(to_node_pid, :get_state)

    [expected_data_one, expected_data_two, expected_data_three] = [0.0, 0.0, 0.0]
    {received_synapse_one, received_synapse_two, received_synapse_three} = updated_test_state.received_synapses

    assert received_synapse_one.connection_id == connection_id_one
    assert_in_delta received_synapse_one.value, expected_data_one, 0.001
    assert received_synapse_one.from_node_id == self()

    assert received_synapse_two.connection_id == connection_id_two
    assert_in_delta received_synapse_two.value, expected_data_two, 0.001
    assert received_synapse_two.from_node_id == self()

    assert received_synapse_three.connection_id == connection_id_three
    assert_in_delta received_synapse_three.value, expected_data_three, 0.001
    assert received_synapse_three.from_node_id == self()
  end

  test ":synchronize should send sensor data synapses to outbound nodes" do
    sensor_data = [1, 2, 3]
    sync_function = {0, fn () -> sensor_data end}
    {:ok, to_node_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    connection_id_one = 8
    connection_id_two = 3
    connection_id_three = 6

    {:ok, sensor_pid} = GenServer.start_link(Sensor,%Sensor{sync_function: sync_function})

    GenServer.call(sensor_pid, {:add_outbound_connection, {to_node_pid, connection_id_one}})
    GenServer.call(sensor_pid, {:add_outbound_connection, {to_node_pid, connection_id_two}})
    GenServer.call(sensor_pid, {:add_outbound_connection, {to_node_pid, connection_id_three}})

    GenServer.call(sensor_pid, :synchronize)

    :timer.sleep(5)
    updated_test_state = GenServer.call(to_node_pid, :get_state)

    [expected_data_one, expected_data_two, expected_data_three] = sensor_data
    {received_synapse_one, received_synapse_two, received_synapse_three} = updated_test_state.received_synapses

    assert received_synapse_one.connection_id == connection_id_one
    assert_in_delta received_synapse_one.value, expected_data_one, 0.001
    assert received_synapse_one.from_node_id == sensor_pid

    assert received_synapse_two.connection_id == connection_id_two
    assert_in_delta received_synapse_two.value, expected_data_two, 0.001
    assert received_synapse_two.from_node_id == sensor_pid

    assert received_synapse_three.connection_id == connection_id_three
    assert_in_delta received_synapse_three.value, expected_data_three, 0.001
    assert received_synapse_three.from_node_id == sensor_pid
  end

  test ":synchronize should send blank sensor data synapses to outbound nodes when no sensor data is available" do
    sensor_data = []
    sync_function = {0, fn () -> sensor_data end}
    {:ok, to_node_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    connection_id_one = 8
    connection_id_two = 3
    connection_id_three = 6

    {:ok, sensor_pid} = GenServer.start_link(Sensor,%Sensor{sync_function: sync_function})

    GenServer.call(sensor_pid, {:add_outbound_connection, {to_node_pid, connection_id_one}})
    GenServer.call(sensor_pid, {:add_outbound_connection, {to_node_pid, connection_id_two}})
    GenServer.call(sensor_pid, {:add_outbound_connection, {to_node_pid, connection_id_three}})

    GenServer.call(sensor_pid, :synchronize)

    :timer.sleep(5)
    updated_test_state = GenServer.call(to_node_pid, :get_state)

    [expected_data_one, expected_data_two, expected_data_three] = [0.0, 0.0, 0.0]
    {received_synapse_one, received_synapse_two, received_synapse_three} = updated_test_state.received_synapses

    assert received_synapse_one.connection_id == connection_id_one
    assert_in_delta received_synapse_one.value, expected_data_one, 0.001
    assert received_synapse_one.from_node_id == sensor_pid

    assert received_synapse_two.connection_id == connection_id_two
    assert_in_delta received_synapse_two.value, expected_data_two, 0.001
    assert received_synapse_two.from_node_id == sensor_pid

    assert received_synapse_three.connection_id == connection_id_three
    assert_in_delta received_synapse_three.value, expected_data_three, 0.001
    assert received_synapse_three.from_node_id == sensor_pid
  end

end
