defmodule Server do
  require Logger

  # by default big endian and binary data (string is binary in elixir)
  def start(port) do
    tcp_manager_pid = spawn(fn -> tcp_manager_loop([]) end)

    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])

    Logger.info("Serwer nasłuchuje na połączenia TCP na porcie: #{port}")
    loop_acceptor(socket, tcp_manager_pid, 0)
  end

  defp loop_acceptor(socket, tcp_manager_pid, client_id) do
    {:ok, client} = :gen_tcp.accept(socket)
    worker_pid = spawn(fn -> serve_tcp_client(client, tcp_manager_pid, client_id) end)
    :ok = :gen_tcp.controlling_process(client, worker_pid)

    Logger.info(
      "Klient z ID: #{client_id} został uruchomiony na procesie z PID: #{inspect(worker_pid)}"
    )

    loop_acceptor(socket, tcp_manager_pid, client_id + 1)
  end

  defp serve_tcp_client(socket, manager_pid, client_id) do
    send(manager_pid, {:register, self()})
    :inet.setopts(socket, active: true)
    worker_loop(socket, manager_pid, client_id)
  end

  defp worker_loop(socket, manager_pid, client_id) do
    receive do
      {:tcp, socket, data} ->
        message = "Klient z ID: #{client_id} wysłał wiadomość: #{data}"
        send(manager_pid, {:broadcast, self(), message})

        Logger.info("Klient z ID: #{client_id} wysłał wiadomość TCP BROADCAST")

        worker_loop(socket, manager_pid, client_id)

      {:broadcast, msg} ->
        :gen_tcp.send(socket, msg)
        worker_loop(socket, manager_pid, client_id)

      {:tcp_closed, ^socket} ->
        message = "Klient z ID: #{client_id} rozłączył się!"
        send(manager_pid, {:broadcast, self(), message})
        send(manager_pid, {:unregister, self()})

        Logger.info("Klient z ID: #{client_id} rozłączył sie")
    end
  end

  defp tcp_manager_loop(clients) do
    receive do
      {:register, pid} ->
        Logger.info(
          "Zarejestrował się u managera: #{inspect(pid)}, łącznie już: #{inspect(clients)}"
        )

        tcp_manager_loop([pid | clients])

      {:broadcast, sender_pid, msg} ->
        for client_pid <- clients, client_pid != sender_pid do
          send(client_pid, {:broadcast, msg})
        end

        tcp_manager_loop(clients)

      {:unregister, pid} ->
        tcp_manager_loop(List.delete(clients, pid))
    end
  end
end
