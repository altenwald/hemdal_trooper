defmodule Hemdal.Host.Trooper do
  @moduledoc """
  Implement the Hemdal.Host behaviour to provide access via SSH to remote
  hosts. The configuration is provided via the host configuration, see
  `Hemdal.Config` for further information.
  """
  use Hemdal.Host

  @rsa_header "-----BEGIN RSA PRIVATE KEY-----"
  @ecdsa_header "-----BEGIN EC PRIVATE KEY-----"

  @default_idle_timeout :timer.minutes(1)

  @impl Hemdal.Host
  def transaction(host, f) do
    host_opts = Map.new(host.options)

    opts =
      [
        host: String.to_charlist(host_opts.hostname),
        port: host_opts.port,
        user: String.to_charlist(host_opts.username)
      ] ++ auth_cfg(host_opts)

    :trooper_ssh.transaction(opts, f)
  end

  @impl Hemdal.Host
  def exec(trooper, command) do
    :trooper_ssh.exec(trooper, String.to_charlist(command))
  end

  @impl Hemdal.Host
  def exec_interactive(trooper, command, client_pid, opts) do
    exec_pid = :trooper_ssh.exec_long_polling(trooper, String.to_charlist(command))
    send(client_pid, {:start, self()})
    output = if(opts[:output], do: "")
    get_and_send_all(client_pid, exec_pid, opts, output, 0)
  end

  @impl Hemdal.Host
  def shell(trooper, client_pid, opts) do
    exec_pid = :trooper_ssh.shell(trooper)
    send(client_pid, {:start, self()})
    output = if(opts[:output], do: "")
    get_and_send_all(client_pid, exec_pid, opts, output, 0)
  end

  defp get_and_send_all(client_pid, exec_pid, opts, output, exit_status) do
    receive do
      {:data, data} ->
        send(exec_pid, {:send, data})
        get_and_send_all(client_pid, exec_pid, opts, output, exit_status)

      :close ->
        #  TODO
        get_and_send_all(client_pid, exec_pid, opts, output, exit_status)

      {:continue, data} ->
        send(client_pid, {:continue, data})
        output = if(output, do: output <> data)
        get_and_send_all(client_pid, exec_pid, opts, output, exit_status)

      {:exit_status, exit_status} ->
        get_and_send_all(client_pid, exec_pid, opts, output, exit_status)

      :closed ->
        send(client_pid, :closed)
        {:ok, exit_status, output}
    after
      opts[:timeout] || @default_idle_timeout ->
        send(exec_pid, :stop)
        send(client_pid, :closed)
        {:ok, 127, output}
    end
  end

  @impl Hemdal.Host
  def write_file(trooper, tmp_file, content) do
    :trooper_scp.write_file(trooper, String.to_charlist(tmp_file), String.to_charlist(content))
  end

  @impl Hemdal.Host
  def delete(trooper, tmp_file) do
    :trooper_scp.delete(trooper, tmp_file)
  end

  defp auth_cfg(%{type: "password", password: password}) do
    [password: String.to_charlist(password)]
  end

  defp auth_cfg(%{type: "rsa", cert_key: rsa} = cred) do
    if not String.starts_with?(rsa, @rsa_header) do
      throw({:error, "Host with an invalid certificate"})
    end

    case cred[:password] do
      nil -> [id_rsa: rsa]
      password -> [id_rsa: rsa, rsa_pass_phrase: password]
    end
  end

  defp auth_cfg(%{type: "ecdsa", cert_key: ecdsa} = cred) do
    if not String.starts_with?(ecdsa, @ecdsa_header) do
      throw({:error, "Host with an invalid certificate"})
    end

    case cred[:password] do
      nil -> [id_ecdsa: ecdsa]
      password -> [id_ecdsa: ecdsa, dsa_pass_phrase: password]
    end
  end
end
