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

    test "deposit/3 returns the expected state" do
      user = generate_user_name()
      {:ok, pid} = Bank.create_user user
      Bank.deposit user, 10, @default_currency
      assert %{balance: 10.0, default_currency: @default_currency, id: nil} = :sys.get_state pid
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

    test "deposit/3 has the correct return value" do
      user = generate_user_name()
      {:ok, _pid} = Bank.create_user user
      assert {:ok, 10.0} = Bank.deposit user, 10, @default_currency
    end
  end

  defp generate_user_name() do
    "user-#{DateTime.utc_now}"
  end
end
