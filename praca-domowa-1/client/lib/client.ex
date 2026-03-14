defmodule Client do
  require Logger

  def start(port) do
    {:ok, socket} =
      :gen_tcp.connect('localhost', port, [:binary, packet: 4, active: true, reuseaddr: true])

    receiver_pid = spawn(fn -> receiver_loop(socket, self()) end)
    :gen_tcp.controlling_process(socket, receiver_pid)
    sender_loop(socket, receiver_pid)
  end

  defp sender_loop(socket, receiver_pid) do
    input = IO.gets("Wiadomość: ")

    # if input == "art" do
    #   send_ascii_art(socket)
    # else
    #   send(receiver_pid, input)
    # end

    send(receiver_pid, {:send, input})
    sender_loop(socket, receiver_pid)
  end

  defp receiver_loop(socket, sender_pid) do
    receive do
      {:tcp, ^socket, data} ->
        IO.puts("\n[Server] #{data}")
        receiver_loop(socket)

      {:send, input} ->
        :gen_tcp.send(socket, input)
        receiver_loop(socket)

      {:tcp_closed, ^socket} ->
        Process.exit(sender_pid, :kill)
        Logger.info("Serwer wyłączył się")
    end
  end

  defp send_ascii_art(socket) do
    art = """
      /\\_/\\
     ( o.o )
      > ^ <
    """
  end
end
