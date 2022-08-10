defmodule Hemdal.Host.TrooperTest do
  use ExUnit.Case
  require Logger

  alias Hemdal.Check

  def get_path_for(uri) do
    Path.join([__DIR__, "..", uri])
  end

  def start_daemon(port) do
    :ok = :ssh.start()

    opts = [
      system_dir: String.to_charlist(get_path_for("daemon1")),
      user_dir: String.to_charlist(get_path_for("user"))
    ]

    {:ok, sshd} = :ssh.daemon(port, opts)
    {:ok, [{:port, ^port} | _]} = :ssh.daemon_info(sshd)
    {:ok, sshd}
  end

  def stop_daemon(sshd) do
    :ok = :ssh.stop_listener(sshd)
    :ok = :ssh.stop_daemon(sshd)
    :ok = :ssh.stop()
    :ok
  end

  setup do
    Application.put_env(:hemdal, :config_module, Hemdal.Config.Backend.Json)
    Application.put_env(:hemdal, Hemdal.Config,
      hosts_file: "test/resources/hosts_config.json",
      alerts_file: "test/resources/alerts_config.json")
  end

  test "get correct alert check" do
    alert_id = "aea48656-be08-4576-a2d0-2723458faefd"
    alert = Hemdal.Config.get_alert_by_id!(alert_id)
    {:ok, _cap} = Hemdal.Event.Mock.start_link()
    {:ok, sshd} = start_daemon(alert.host.port)
    {:ok, pid} = Check.update_alert(alert)
    assert pid == Check.get_pid(alert.id)

    assert_receive {:event, _from, %{alert: %{id: ^alert_id}, status: :ok}}, 1_500
    refute_receive _, 500

    status = Check.get_status(alert.id)
    assert %{"status" => :ok, "result" => %{"message" => "valid one!"}} = status

    Hemdal.Event.Log.stop()
    Check.stop(pid)
    :ok = stop_daemon(sshd)
  end

  test "get failing and broken alert check but with a working script" do
    alert_id = "6b6d247c-48c3-4a8c-9b4f-773f178ddc0f"
    alert = Hemdal.Config.get_alert_by_id!(alert_id)
    {:ok, _cap} = Hemdal.Event.Mock.start_link()
    {:ok, sshd} = start_daemon(alert.host.port)
    {:ok, pid} = Check.update_alert(alert)
    assert pid == Check.get_pid(alert.id)

    assert_receive {:event, _from, %{alert: %{id: ^alert_id}, status: :warn}}, 5_000
    assert_receive {:event, _from, %{alert: %{id: ^alert_id}, status: :error}}, 5_000
    refute_receive _, 500

    status = Check.get_status(alert.id)
    assert %{"status" => :error, "result" => %{"message" => "invalid one!"}} = status

    Hemdal.Event.Log.stop()
    Check.stop(alert.id)
    :ok = stop_daemon(sshd)
  end
end
