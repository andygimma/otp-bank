defmodule BankTest do
  use ExUnit.Case
  doctest Bank

  @default_currency "USD"

  setup_all do
    assert {:ok, pid} = Bank.Server.start
    on_exit(:kill_process, fn ->
      Process.exit(pid, :shutdown)
    end)
  end

  describe "OTP" do
    test "create_user/1 returns the expected state" do
      {:ok, pid} = Bank.create_user generate_user_name()
      assert %{balance: 0.0, default_currency: @default_currency, id: nil} = :sys.get_state pid
    end
  end

  describe "Public API" do
    test "create_user/1 has the correct return value" do
      Bank.Server.start
      assert {:ok, _pid} = Bank.create_user generate_user_name()
    end

    test "create_user/1 handles bad params" do
      Bank.Server.start
      assert {:error, :wrong_arguments} = Bank.create_user 12345
    end
  end

  defp generate_user_name() do
    "user-#{DateTime.utc_now}"
  end
end
