defmodule Kadabra.ConnectionTest do
  use ExUnit.Case

  @uri 'https://httpbin.org'

  test "closes active streams on socket close" do
    {:ok, pid} = Kadabra.open(@uri)
    ref = Process.monitor(pid)

    # Open two streams that send the time every second
    Kadabra.get(pid, "/get", on_response: & &1)
    Kadabra.get(pid, "/get", on_response: & &1)

    conn_pid = :sys.get_state(pid).connection
    socket_pid = :sys.get_state(conn_pid).config.socket

    # Wait to collect some data on the streams
    Process.sleep(500)

    state = :sys.get_state(conn_pid)
    assert Enum.count(state.flow_control.stream_set.active_streams) == 2

    # frame = Kadabra.Frame.Goaway.new(1)
    # GenServer.cast(conn_pid, {:recv, frame})
    send(socket_pid, {:ssl_closed, nil})

    assert_receive {:closed, ^pid}, 5_000
    assert_receive {:DOWN, ^ref, :process, ^pid, :shutdown}, 5_000
  end

  test "closes active streams on socket error" do
    {:ok, pid} = Kadabra.open(@uri)
    ref = Process.monitor(pid)

    # Open two streams that send the time every second
    Kadabra.get(pid, "/get", on_response: & &1)
    Kadabra.get(pid, "/get", on_response: & &1)

    conn_pid = :sys.get_state(pid).connection
    socket_pid = :sys.get_state(conn_pid).config.socket

    Process.sleep(500)

    state = :sys.get_state(conn_pid)
    assert Enum.count(state.flow_control.stream_set.active_streams) == 2

    send(socket_pid, {:ssl_error, nil, "some reason"})

    assert_receive {:closed, ^pid}, 5_000
    assert_receive {:DOWN, ^ref, :process, ^pid, :shutdown}, 5_000
  end
end
