defmodule Server do
  # by default big endian and binary data (string is binary in elixir)
  def start(port) do
    {:ok, tcp_socket} =
      :gen_tcp.listen(port, [:binary, packet: 4, active: false, reuseaddr: true])

    {:ok, udp_socket} =
      :gen_udp.open(port, [:binary, active: true, reuseaddr: true, broadcast: true])

    manager = Server.Manager.start(udp_socket)

    Server.Udp.start(udp_socket, manager)
    Server.Tcp.start(tcp_socket, manager)
  end
end
