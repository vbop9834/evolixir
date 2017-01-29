defmodule Evolixir.SensorTest do
  use ExUnit.Case
  doctest Sensor

  test "send_synapse_to_outbound_connection should send a synapse to the supplied pid" do
    data = 0.38
    {:ok, to_node_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    connection_id = 5
    fake_sensor_id = 8

    Sensor.send_synapse_to_outbound_connection(nil, fake_sensor_id, data, to_node_pid, connection_id)

    :timer.sleep(5)
    updated_test_state = GenServer.call(to_node_pid, :get_state)

    {received_synapse} = updated_test_state.received_synapses
    assert received_synapse.connection_id == connection_id
    assert_in_delta received_synapse.value, data, 0.001
    assert received_synapse.from_node_id == fake_sensor_id
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
    fake_sensor_id = :sensor
    Sensor.process_sensor_data(nil, fake_sensor_id, sensor_data, outbound_connections)

    :timer.sleep(5)
    updated_test_state = GenServer.call(to_node_pid, :get_state)

    [expected_data_one, expected_data_two, expected_data_three] = sensor_data
    {received_synapse_one, received_synapse_two, received_synapse_three} = updated_test_state.received_synapses

    assert received_synapse_one.connection_id == connection_id_one
    assert_in_delta received_synapse_one.value, expected_data_one, 0.001
    assert received_synapse_one.from_node_id == fake_sensor_id

    assert received_synapse_two.connection_id == connection_id_two
    assert_in_delta received_synapse_two.value, expected_data_two, 0.001
    assert received_synapse_two.from_node_id == fake_sensor_id

    assert received_synapse_three.connection_id == connection_id_three
    assert_in_delta received_synapse_three.value, expected_data_three, 0.001
    assert received_synapse_three.from_node_id == fake_sensor_id
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
    fake_sensor_id = 9
    Sensor.process_sensor_data(nil, fake_sensor_id, sensor_data, outbound_connections)

    :timer.sleep(5)
    updated_test_state = GenServer.call(to_node_pid, :get_state)

    [expected_data_one] = sensor_data
    {received_synapse_one, received_synapse_two, received_synapse_three} = updated_test_state.received_synapses

    assert received_synapse_one.connection_id == connection_id_one
    assert_in_delta received_synapse_one.value, expected_data_one, 0.001
    assert received_synapse_one.from_node_id == fake_sensor_id

    assert received_synapse_two.connection_id == connection_id_two
    assert_in_delta received_synapse_two.value, 0.0, 0.001
    assert received_synapse_two.from_node_id == fake_sensor_id

    assert received_synapse_three.connection_id == connection_id_three
    assert_in_delta received_synapse_three.value, 0.0, 0.001
    assert received_synapse_three.from_node_id == fake_sensor_id
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
    fake_sensor_id = 9
    Sensor.synchronize(nil, fake_sensor_id, sync_function, outbound_connections)

    :timer.sleep(5)
    updated_test_state = GenServer.call(to_node_pid, :get_state)

    [expected_data_one, expected_data_two, expected_data_three] = sensor_data
    {received_synapse_one, received_synapse_two, received_synapse_three} = updated_test_state.received_synapses

    assert received_synapse_one.connection_id == connection_id_one
    assert_in_delta received_synapse_one.value, expected_data_one, 0.001
    assert received_synapse_one.from_node_id == fake_sensor_id

    assert received_synapse_two.connection_id == connection_id_two
    assert_in_delta received_synapse_two.value, expected_data_two, 0.001
    assert received_synapse_two.from_node_id == fake_sensor_id

    assert received_synapse_three.connection_id == connection_id_three
    assert_in_delta received_synapse_three.value, expected_data_three, 0.001
    assert received_synapse_three.from_node_id == fake_sensor_id
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
    fake_sensor_id = 9
    Sensor.synchronize(nil, fake_sensor_id, sync_function, outbound_connections)

    :timer.sleep(5)
    updated_test_state = GenServer.call(to_node_pid, :get_state)

    [expected_data_one, expected_data_two, expected_data_three] = [0.0, 0.0, 0.0]
    {received_synapse_one, received_synapse_two, received_synapse_three} = updated_test_state.received_synapses

    assert received_synapse_one.connection_id == connection_id_one
    assert_in_delta received_synapse_one.value, expected_data_one, 0.001
    assert received_synapse_one.from_node_id == fake_sensor_id

    assert received_synapse_two.connection_id == connection_id_two
    assert_in_delta received_synapse_two.value, expected_data_two, 0.001
    assert received_synapse_two.from_node_id == fake_sensor_id

    assert received_synapse_three.connection_id == connection_id_three
    assert_in_delta received_synapse_three.value, expected_data_three, 0.001
    assert received_synapse_three.from_node_id == fake_sensor_id
  end

  test ":synchronize should send sensor data synapses to outbound nodes" do
    sensor_data = [1, 2, 3]
    sync_function = {0, fn () -> sensor_data end}
    {:ok, to_node_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    connection_id_one = 8
    connection_id_two = 3
    connection_id_three = 6
    outbound_connections = [
      {to_node_pid, connection_id_one},
      {to_node_pid, connection_id_two},
      {to_node_pid, connection_id_three}
    ]

    sensor_name = :sensor
    {:ok, _sensor_pid} = GenServer.start_link(Sensor,
      %Sensor{
        sync_function: sync_function,
        outbound_connections: outbound_connections,
        sensor_id: sensor_name
      }, name: sensor_name)

    GenServer.call(sensor_name, :synchronize)

    :timer.sleep(5)
    updated_test_state = GenServer.call(to_node_pid, :get_state)

    [expected_data_one, expected_data_two, expected_data_three] = sensor_data
    {received_synapse_one, received_synapse_two, received_synapse_three} = updated_test_state.received_synapses

    assert received_synapse_one.connection_id == connection_id_one
    assert_in_delta received_synapse_one.value, expected_data_one, 0.001
    assert received_synapse_one.from_node_id == sensor_name

    assert received_synapse_two.connection_id == connection_id_two
    assert_in_delta received_synapse_two.value, expected_data_two, 0.001
    assert received_synapse_two.from_node_id == sensor_name

    assert received_synapse_three.connection_id == connection_id_three
    assert_in_delta received_synapse_three.value, expected_data_three, 0.001
    assert received_synapse_three.from_node_id == sensor_name
  end

  test ":synchronize should send blank sensor data synapses to outbound nodes when no sensor data is available" do
    sensor_data = []
    sync_function = {0, fn () -> sensor_data end}
    {:ok, to_node_pid} = GenServer.start_link(NodeTestHelper, %NodeTestHelper{})
    connection_id_one = 8
    connection_id_two = 3
    connection_id_three = 6
    outbound_connections = [
      {to_node_pid, connection_id_one},
      {to_node_pid, connection_id_two},
      {to_node_pid, connection_id_three}
    ]

    sensor_name = :sensor
    {:ok, _sensor_pid} = GenServer.start_link(Sensor,
      %Sensor{
        sensor_id: sensor_name,
        sync_function: sync_function,
        outbound_connections: outbound_connections
      }, name: sensor_name)

    GenServer.call(sensor_name, :synchronize)

    :timer.sleep(5)
    updated_test_state = GenServer.call(to_node_pid, :get_state)

    [expected_data_one, expected_data_two, expected_data_three] = [0.0, 0.0, 0.0]
    {received_synapse_one, received_synapse_two, received_synapse_three} = updated_test_state.received_synapses

    assert received_synapse_one.connection_id == connection_id_one
    assert_in_delta received_synapse_one.value, expected_data_one, 0.001
    assert received_synapse_one.from_node_id == sensor_name

    assert received_synapse_two.connection_id == connection_id_two
    assert_in_delta received_synapse_two.value, expected_data_two, 0.001
    assert received_synapse_two.from_node_id == sensor_name

    assert received_synapse_three.connection_id == connection_id_three
    assert_in_delta received_synapse_three.value, expected_data_three, 0.001
    assert received_synapse_three.from_node_id == sensor_name
  end

end
