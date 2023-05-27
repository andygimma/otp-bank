defmodule BankTest do
  use ExUnit.Case
  doctest Bank

  describe "OTP" do
    test "the server starts" do
      assert {:ok, _pid} = Bank.Server.start
    end

    test "a newly created user has expected state" do
      Bank.Server.start
      {:ok, pid} = Bank.create_user "user"
      assert %{balance: 0.0, default_currency: "USD", id: nil} = :sys.get_state pid
    end
  end

  describe "Public API" do
    test "create a user happy path" do
      Bank.Server.start
      assert {:ok, _pid} = Bank.create_user "user"
    end

    test "create a user with bad args" do
      Bank.Server.start
      assert {:error, :wrong_arguments} = Bank.create_user 12345
    end
  end

end
