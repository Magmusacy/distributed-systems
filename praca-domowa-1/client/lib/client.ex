defmodule Client do
  require Logger

  @multicast_group {239, 0, 0, 1}
  @multicast_port 6767

  def start(port, name) do
    {:ok, tcp_socket} =
      :gen_tcp.connect('localhost', port, [:binary, packet: 4, active: true, reuseaddr: true])

    # Give this client a name
    :gen_tcp.send(tcp_socket, name)
    {:ok, {_, tcp_port}} = :inet.sockname(tcp_socket)

    # Per client UDP socket
    {:ok, udp_socket} = :gen_udp.open(tcp_port, [:binary, active: true])
    :ok = :gen_udp.connect(udp_socket, 'localhost', port)

    # Multicast UDP socket
    {:ok, multicast_udp_socket} =
      :gen_udp.open(@multicast_port, [
        :binary,
        active: true,
        reuseaddr: true,
        reuseport: true,
        add_membership: {@multicast_group, {0, 0, 0, 0}},
        multicast_loop: true
      ])

    receiver_state = %{
      tcp_socket: tcp_socket,
      udp_socket: udp_socket,
      multicast_udp_socket: multicast_udp_socket,
      sender_pid: self()
    }

    receiver_pid = spawn(fn -> receiver_loop(receiver_state) end)

    :gen_tcp.controlling_process(tcp_socket, receiver_pid)
    :gen_udp.controlling_process(udp_socket, receiver_pid)
    :gen_udp.controlling_process(multicast_udp_socket, receiver_pid)

    sender_state = %{
      tcp_socket: tcp_socket,
      udp_socket: udp_socket,
      receiver_pid: receiver_pid,
      mode: :tcp
    }

    IO.puts("Wysyłaj wiadomości na jednym z trzech kanałów (t/u/m)")
    sender_loop(sender_state)
  end

  defp sender_loop(state) do
    input = IO.gets("Wiadomość: ")

    new_mode =
      cond do
        String.trim(input) == "u" ->
          IO.write("Przełączono na tryb UDP")
          :udp

        String.trim(input) == "t" ->
          IO.write("Przełączono na tryb TCP")
          :tcp

        String.trim(input) == "m" ->
          IO.write("Przełączono na tryb MULTICAST")
          :multicast

        # Testing purposes
        String.trim(input) == "art" ->
          send(
            state.receiver_pid,
            {:send, state.mode,
             """

               /\\_/\\
              ( o.o )
               > ^ <
             """}
          )

          state.mode

        true ->
          send(state.receiver_pid, {:send, state.mode, input})
          state.mode
      end

    sender_loop(%{state | mode: new_mode})
  end

  defp receiver_loop(state) do
    %{
      tcp_socket: tcp_socket,
      udp_socket: udp_socket,
      multicast_udp_socket: multicast_udp_socket,
      sender_pid: sender_pid
    } = state

    receive do
      {:tcp, ^tcp_socket, data} ->
        IO.write("[Server (TCP)] #{data}")
        receiver_loop(state)

      {:udp, ^udp_socket, _host, _port, data} ->
        IO.write("[Server (UDP)] #{data}")
        receiver_loop(state)

      {:udp, ^multicast_udp_socket, _host, _port, data} ->
        IO.write("[MULTICAST] #{data}")
        receiver_loop(state)

      {:send, mode, input} ->
        case mode do
          :tcp ->
            :gen_tcp.send(tcp_socket, input)

          :udp ->
            :gen_udp.send(udp_socket, input)

          :multicast ->
            :gen_udp.send(multicast_udp_socket, @multicast_group, @multicast_port, input)
        end

        receiver_loop(state)

      {:tcp_closed, ^tcp_socket} ->
        Process.exit(sender_pid, :kill)
        IO.write("Serwer wyłączył się")
    end
  end
end
