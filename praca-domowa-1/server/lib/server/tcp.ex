defmodule Server.Tcp do
  require Logger

  def start(socket, manager_pid) do
    Logger.info("Serwer nasłuchuje połaczeń TCP")
    listening_loop(socket, manager_pid)
  end

  defp listening_loop(socket, manager_pid) do
    {:ok, client} = :gen_tcp.accept(socket)
    worker_pid = spawn(fn -> serve(client, manager_pid) end)
    :ok = :gen_tcp.controlling_process(client, worker_pid)

    listening_loop(socket, manager_pid)
  end

  defp serve(socket, manager_pid) do
    {:ok, name} = :gen_tcp.recv(socket, 0)
    :inet.setopts(socket, active: true)
    send(manager_pid, {:register, name, self(), :inet.peername(socket)})
    worker_loop(socket, manager_pid, name)
  end

  defp worker_loop(socket, manager_pid, name) do
    receive do
      {:tcp, ^socket, data} ->
        message = "#{name} wysłał wiadomość: #{data}"
        send(manager_pid, {:tcp_broadcast, self(), message})
        worker_loop(socket, manager_pid, name)

      {:tcp_broadcast, msg} ->
        :gen_tcp.send(socket, msg)
        worker_loop(socket, manager_pid, name)

      {:tcp_closed, ^socket} ->
        message = "#{name} rozłączył się!"
        send(manager_pid, {:broadcast, self(), message})
        send(manager_pid, {:unregister, self()})

        Logger.info("#{name} rozłączył sie")
    end
  end
end
