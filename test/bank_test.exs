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

    test "withdraw/3 returns the expected state" do
      user = generate_user_name()
      {:ok, pid} = Bank.create_user user
      Bank.deposit user, 10, @default_currency
      Bank.withdraw user, 5, @default_currency
      assert %{balance: 5.0, default_currency: @default_currency, id: nil} = :sys.get_state pid
    end

    test "send/4 returns the expected states" do
      user_1 = generate_user_name()
      user_2 = generate_user_name()

      {:ok, pid_1} = Bank.create_user user_1
      {:ok, pid_2} = Bank.create_user user_2

      Bank.deposit user_1, 10, @default_currency
      Bank.send user_1, user_2, 2, @default_currency
      assert %{balance: 8.0, default_currency: @default_currency, id: nil} = :sys.get_state pid_1
      assert %{balance: 2.0, default_currency: @default_currency, id: nil} = :sys.get_state pid_2
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

    test "deposit/3 when the user does not exist" do
      user_1 = generate_user_name()
      user_2 = generate_user_name()

      {:ok, _pid} = Bank.create_user user_1
      assert {:error, :user_does_not_exist} = Bank.deposit user_2, 10, @default_currency
    end

    test "deposit/3 handles bad params" do
      Bank.Server.start
      assert {:error, :wrong_arguments} = Bank.deposit 12345, "10", 54321
    end


    test "withdraw/3 has the correct return value" do
      user = generate_user_name()
      {:ok, _pid} = Bank.create_user user
      Bank.deposit user, 10, @default_currency
      assert {:ok, 5.0} = Bank.withdraw user, 5, @default_currency
    end

    test "withdraw/3 when the user does not have enough money" do
      user = generate_user_name()

      {:ok, _pid} = Bank.create_user user
      {:error, :not_enough_money} = Bank.withdraw user, 5, @default_currency
    end

    test "withdraw/3 when the user does not exist" do
      user_1 = generate_user_name()
      user_2 = generate_user_name()

      {:ok, _pid} = Bank.create_user user_1
      assert {:error, :user_does_not_exist} = Bank.withdraw user_2, 10, @default_currency
    end

    test "withdraw/3 handles bad params" do
      Bank.Server.start
      assert {:error, :wrong_arguments} = Bank.withdraw 12345, "10", 54321
    end

    test "get_balance/2 has the correct return value" do
      user = generate_user_name()
      {:ok, _pid} = Bank.create_user user
      Bank.deposit user, 10, @default_currency
      assert {:ok, 10.0} = Bank.get_balance user, @default_currency
    end

    test "get_balance/2 when the user does not exist" do
      user_1 = generate_user_name()
      user_2 = generate_user_name()

      {:ok, _pid} = Bank.create_user user_1
      assert {:error, :user_does_not_exist} = Bank.get_balance user_2, @default_currency
    end

    test "get_balance/2 handles bad params" do
      Bank.Server.start
      assert {:error, :wrong_arguments} = Bank.get_balance 12345, 54321
    end

    test "send/4 has the correct return value" do
      user_1 = generate_user_name()
      user_2 = generate_user_name()

      {:ok, _pid_1} = Bank.create_user user_1
      {:ok, _pid_2} = Bank.create_user user_2

      Bank.deposit user_1, 10, @default_currency
      assert {:ok, 8.0, 2.0} = Bank.send user_1, user_2, 2, @default_currency
    end

    test "send/4 handles not enough money" do
      user_1 = generate_user_name()
      user_2 = generate_user_name()

      Bank.create_user user_1
      Bank.create_user user_2

      Bank.deposit user_1, 10, @default_currency
      assert {:error, :not_enough_money} = Bank.send user_1, user_2, 20, @default_currency
    end

    test "send/4 sender does not exist" do
      user_1 = generate_user_name()
      user_2 = generate_user_name()

      Bank.create_user user_1
      Bank.create_user user_2

      Bank.deposit user_1, 10, @default_currency
      assert {:error, :sender_does_not_exist} = Bank.send "SOME USER", user_2, 20, @default_currency
    end

    test "send/4 receiver does not exist" do
      user_1 = generate_user_name()
      user_2 = generate_user_name()

      Bank.create_user user_1
      Bank.create_user user_2

      Bank.deposit user_1, 10, @default_currency
      assert {:error, :receiver_does_not_exist} = Bank.send user_2, "SOME USER", 20, @default_currency
    end

    test "send/4 handles bad params" do
      Bank.Server.start
      assert {:error, :wrong_arguments} = Bank.send 1, 2, 3, 4
    end
  end

  defp generate_user_name() do
    "user-#{DateTime.utc_now}"
  end
end
