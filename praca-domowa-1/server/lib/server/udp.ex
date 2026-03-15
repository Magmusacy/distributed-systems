defmodule Server.Udp do
  require Logger

  def start(socket, manager_pid) do
    worker_pid = spawn(fn -> worker_loop(socket, manager_pid) end)
    :gen_udp.controlling_process(socket, worker_pid)
    Logger.info("Serwer nasłuchuje połaczeń UDP")
  end

  defp worker_loop(socket, manager_pid) do
    receive do
      {:udp, ^socket, host, port, data} ->
        send(manager_pid, {:get_name, host, port, self()})

        receive do
          {:name_result, name} ->
            message = "#{name} wysłał wiadomość: #{data}"
            Logger.info(message)
            send(manager_pid, {:udp_broadcast, {host, port}, message})
            worker_loop(socket, manager_pid)
        end
    end
  end
end
