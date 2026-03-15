defmodule Client do
  require Logger

  def start(port, name) do
    {:ok, tcp_socket} =
      :gen_tcp.connect('localhost', port, [:binary, packet: 4, active: true, reuseaddr: true])

    # Give this client a name
    :gen_tcp.send(tcp_socket, name)
    {:ok, {_, tcp_port}} = :inet.sockname(tcp_socket)
    {:ok, udp_socket} = :gen_udp.open(tcp_port, [:binary, active: true])
    :ok = :gen_udp.connect(udp_socket, 'localhost', port)

    receiver_pid = spawn(fn -> receiver_loop(tcp_socket, udp_socket, self()) end)
    :gen_tcp.controlling_process(tcp_socket, receiver_pid)
    :gen_udp.controlling_process(udp_socket, receiver_pid)
    sender_loop(tcp_socket, udp_socket, receiver_pid, :tcp)
  end

  defp sender_loop(tcp_socket, udp_socket, receiver_pid, mode) do
    input = IO.gets("Wiadomość: ")

    mode =
      cond do
        mode == :tcp and String.trim(input) == "u" ->
          Logger.info("Przełączono na tryb UDP")
          :udp

        mode == :udp and String.trim(input) == "t" ->
          Logger.info("Przełączono na tryb TCP")
          :tcp

        # Testing purposes
        String.trim(input) == "art" ->
          send(
            receiver_pid,
            {:send, mode,
             """

               /\\_/\\
              ( o.o )
               > ^ <
             """}
          )

          mode

        true ->
          send(receiver_pid, {:send, mode, input})
          mode
      end

    sender_loop(tcp_socket, udp_socket, receiver_pid, mode)
  end

  defp receiver_loop(tcp_socket, udp_socket, sender_pid) do
    receive do
      {:tcp, ^tcp_socket, data} ->
        IO.puts("\n[Server (TCP)] #{data}")
        receiver_loop(tcp_socket, udp_socket, sender_pid)

      {:udp, ^udp_socket, host, port, data} ->
        IO.puts("\n[Server (UDP)] #{data}")
        receiver_loop(tcp_socket, udp_socket, sender_pid)

      {:send, mode, input} ->
        case mode do
          :tcp ->
            Logger.info("Wysyłam TCP")
            :gen_tcp.send(tcp_socket, input)

          :udp ->
            Logger.info("Wysyłam UDP")
            :gen_udp.send(udp_socket, input)
        end

        receiver_loop(tcp_socket, udp_socket, sender_pid)

      {:tcp_closed, ^tcp_socket} ->
        Process.exit(sender_pid, :kill)
        Logger.info("Serwer wyłączył się")

      cos ->
        Logger.info(inspect(cos))
    end
  end
end
