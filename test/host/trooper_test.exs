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
    _ = :ssh.stop_listener(sshd)
    _ = :ssh.stop_daemon(sshd)
    _ = :ssh.stop()
    :ok
  end

  setup do
    Application.put_env(:hemdal, :config_module, Hemdal.Config.Backend.Env)

    Application.put_env(:hemdal, Hemdal.Config, [
      [
        id: "aea48656-be08-4576-a2d0-2723458faefd",
        name: "valid alert check",
        host: [
          id: "2a8572d4-ceb3-4200-8b29-dd1f21b50e54",
          name: "localhost",
          module: Hemdal.Host.Trooper,
          max_workers: 1,
          options: [
            port: 40_400,
            type: "rsa",
            username: "manuel.rubio",
            hostname: "127.0.0.1",
            cert_key: File.read!("test/user/id_rsa"),
            cert_pub: File.read!("test/user/id_rsa.pub")
          ]
        ],
        command: [
          name: "get ok status",
          type: "line",
          command: ~s|"[\\"OK\\", \\"valid one!\\"]".|
        ],
        check_in_sec: 60,
        recheck_in_sec: 1,
        broken_recheck_in_sec: 10,
        retries: 1
      ],
      [
        id: "6b6d247c-48c3-4a8c-9b4f-773f178ddc0f",
        name: "invalid alert check",
        host: [
          id: "fd1393bf-c554-45fe-869a-d253466da8ea",
          name: "localhost",
          module: Hemdal.Host.Trooper,
          max_workers: 1,
          options: [
            port: 50_500,
            type: "rsa",
            username: "manuel.rubio",
            hostname: "127.0.0.1",
            cert_key: File.read!("test/user/id_rsa"),
            cert_pub: File.read!("test/user/id_rsa.pub")
          ]
        ],
        command: [
          name: "get failed status",
          type: "line",
          command: ~s|"[\\"FAIL\\", \\"invalid one!\\"]".|
        ],
        check_in_sec: 60,
        recheck_in_sec: 1,
        broken_recheck_in_sec: 10,
        retries: 1
      ]
    ])
  end

  test "get correct alert check" do
    alert_id = "aea48656-be08-4576-a2d0-2723458faefd"
    alert = Hemdal.Config.get_alert_by_id!(alert_id)
    {:ok, _cap} = Hemdal.Event.Mock.start_link()
    {:ok, sshd} = start_daemon(alert.host.options[:port])
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

  test "run interactive command" do
    alert_id = "aea48656-be08-4576-a2d0-2723458faefd"
    alert = Hemdal.Config.get_alert_by_id!(alert_id)
    {:ok, sshd} = start_daemon(alert.host.options[:port])
    Hemdal.Host.reload_all()

    host_id = "2a8572d4-ceb3-4200-8b29-dd1f21b50e54"

    command = %Hemdal.Config.Alert.Command{
      name: "interactive command",
      type: "interactive",
      command: ~s|io:get_line("").|
    }

    pid =
      spawn(fn ->
        pid =
          receive do
            {:start, pid} -> pid
          end

        send(pid, {:data, ~s|{"status": "OK", "message": "hello world!"}\n|})
        assert_receive {:continue, ~s|{"status": "OK", "message": "hello world!"}\n|}
        send(pid, :close)
        assert_receive :closed
      end)

    assert {:ok, %{"message" => "hello world!", "status" => "OK"}} ==
             Hemdal.Host.exec(host_id, command, [pid])

    :ok = stop_daemon(sshd)
  end

  test "get failing and broken alert check but with a working script" do
    alert_id = "6b6d247c-48c3-4a8c-9b4f-773f178ddc0f"
    alert = Hemdal.Config.get_alert_by_id!(alert_id)
    {:ok, _cap} = Hemdal.Event.Mock.start_link()
    {:ok, sshd} = start_daemon(alert.host.options[:port])
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
