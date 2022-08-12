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
    Application.put_env(:hemdal, :config_module, Hemdal.Config.Backend.Env)

    Application.put_env(:hemdal, Hemdal.Config, [
      [
        id: "aea48656-be08-4576-a2d0-2723458faefd",
        name: "valid alert check",
        host: [
          id: "2a8572d4-ceb3-4200-8b29-dd1f21b50e54",
          name: "127.0.0.1",
          port: 40_400,
          max_workers: 1,
          credential: [
            id: "ff47ed0e-ea1f-4e54-ab4a-c406a78339f7",
            type: "rsa",
            username: "manuel.rubio",
            cert_key: File.read!("test/user/id_rsa"),
            cert_pub: File.read!("test/user/id_rsa.pub")
          ]
        ],
        command: [
          id: "c5c090b2-7b6a-487e-87b8-57788bffaffe",
          name: "get ok status",
          command_type: "line",
          command: "\"[\\\"OK\\\", \\\"valid one!\\\"]\"."
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
          name: "127.0.0.1",
          port: 50_500,
          max_workers: 1,
          credential: [
            id: "ff47ed0e-ea1f-4e54-ab4a-c406a78339f7",
            type: "rsa",
            username: "manuel.rubio",
            cert_key: File.read!("test/user/id_rsa"),
            cert_pub: File.read!("test/user/id_rsa.pub")
          ]
        ],
        command: [
          id: "6b07ea20-f677-44bc-90f4-e07b611068f3",
          name: "get failed status",
          command_type: "line",
          command: "\"[\\\"FAIL\\\", \\\"invalid one!\\\"]\"."
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
