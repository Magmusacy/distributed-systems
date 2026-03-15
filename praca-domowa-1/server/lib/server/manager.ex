defmodule Server.Manager do
  require Logger

  def start(udp_socket) do
    manager_pid = spawn(fn -> manager_loop([], udp_socket) end)
  end

  defp manager_loop(clients, udp_socket) do
    receive do
      {:register, name, pid, {:ok, {host, port}}} ->
        manager_loop([%{name: name, tcp_pid: pid, udp_addr: {host, port}} | clients], udp_socket)

      {:tcp_broadcast, sender_pid, msg} ->
        for %{tcp_pid: tcp_pid} <- clients, tcp_pid != sender_pid do
          send(tcp_pid, {:tcp_broadcast, msg})
        end

        manager_loop(clients, udp_socket)

      {:udp_broadcast, sender_addr, msg} ->
        for %{udp_addr: udp_addr = {host, port}} <- clients, udp_addr != sender_addr do
          :gen_udp.send(udp_socket, host, port, msg)
        end

        manager_loop(clients, udp_socket)

      {:get_name, host, port, sender_pid} ->
        send(
          sender_pid,
          {:name_result,
           Enum.find(clients, fn client -> client.udp_addr == {host, port} end).name}
        )

        manager_loop(clients, udp_socket)

      {:unregister, pid} ->
        manager_loop(
          List.delete(clients, Enum.find(clients, fn client -> client.tcp_pid == pid end)),
          udp_socket
        )
    end
  end
end
