defmodule Hemdal.Host.Trooper do
  @moduledoc """
  Implement the Hemdal.Host behaviour to provide access via SSH to remote
  hosts. The configuration is provided via the host configuration, see
  `Hemdal.Config` for further information.
  """
  use Hemdal.Host

  @rsa_header "-----BEGIN RSA PRIVATE KEY-----"
  @dsa_header "-----BEGIN DSA PRIVATE KEY-----"
  @ecdsa_header "-----BEGIN EC PRIVATE KEY-----"

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
    :trooper_ssh.exec(trooper, command)
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
      password -> [id_rsa: rsa, rsa_pass_pharse: password]
    end
  end

  defp auth_cfg(%{type: "dsa", cert_key: dsa} = cred) do
    if not String.starts_with?(dsa, @dsa_header) do
      throw({:error, "Host with an invalid certificate"})
    end

    case cred[:password] do
      nil -> [id_dsa: dsa]
      password -> [id_dsa: dsa, dsa_pass_pharse: password]
    end
  end

  defp auth_cfg(%{type: "ecdsa", cert_key: ecdsa} = cred) do
    if not String.starts_with?(ecdsa, @ecdsa_header) do
      throw({:error, "Host with an invalid certificate"})
    end

    case cred[:password] do
      nil -> [id_ecdsa: ecdsa]
      password -> [id_ecdsa: ecdsa, dsa_pass_pharse: password]
    end
  end
end
