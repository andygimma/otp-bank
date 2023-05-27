defmodule Bank do
  use GenServer
  require Logger

  @registry :bank_registry
  @default_currency "USD"
  @default_balance 0.0
  @initial_state %{id: nil, balance: @default_balance, default_currency: @default_currency}
  @conversion_map %{
    "USD" => 1,
    "EU" => 2,
    "COP" => 3
  }
  defstruct [:balance, :default_currency, :id]

  ## GenServer API

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: via_tuple(name))
  end

  def stop(process_name, stop_reason) do
    process_name |> via_tuple() |> GenServer.stop(stop_reason)
  end

  def child_spec(process_name) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [process_name]},
      restart: :transient
    }
  end

  @spec create_user(user :: String.t()) :: :ok | {:error, :wrong_arguments | :user_already_exists}
  def create_user(id) when not is_binary(id), do: {:error, :wrong_arguments}

  def create_user(id) do
    Bank.BankSupervisor.start_child(id)
  end

  @spec deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def deposit(user, amount, currency)
      when is_binary(user) and is_number(amount) and is_binary(currency) and is_binary(user) do

    cond do
      !!too_many_requests?() -> {:error, :too_many_requests_to_user}
      !user_exists?(user) -> {:error, :user_does_not_exist}
      true ->
        user |> via_tuple() |> GenServer.call({:deposit, user, amount, currency})
        [{pid, _}] = Registry.lookup(:bank_registry, user)
        {:ok, :sys.get_state(pid).balance}
    end
  end

  def deposit(_, _, _), do: {:error, :wrong_arguments}

  @spec withdraw(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error,
             :wrong_arguments
             | :user_does_not_exist
             | :not_enough_money
             | :too_many_requests_to_user}
  def withdraw(user, amount, currency) do
    cond do
      !!too_many_requests?() -> {:error, :too_many_requests_to_user}
      !user_exists?(user) -> {:error, :user_does_not_exist}
      !enough_in_balance?(user, amount, currency) -> {:error, :not_enough_money}
      true ->
        user |> via_tuple() |> GenServer.call({:withdraw, user, amount, currency})
        [{pid, _}] = Registry.lookup(:bank_registry, user)
        {:ok, :sys.get_state(pid).balance}
    end
  end

  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def get_balance(user, currency) do
    cond do
      !!too_many_requests?() -> {:error, :too_many_requests_to_user}
      !user_exists?(user) -> {:error, :user_does_not_exist}
      true ->
        [{pid, _}] = Registry.lookup(:bank_registry, user)

        converted_balance =
          :sys.get_state(pid).balance
          |> convert_by_currency(currency)

        {:ok, converted_balance}
    end
  end

  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number,
          currency :: String.t()
        ) ::
          {:ok, from_user_balance :: number, to_user_balance :: number}
          | {:error,
             :wrong_arguments
             | :not_enough_money
             | :sender_does_not_exist
             | :receiver_does_not_exist
             | :too_many_requests_to_sender
             | :too_many_requests_to_receiver}
  def send(from_user, to_user, amount, currency)
      when is_binary(from_user) and is_binary(to_user) and is_number(amount) and
             is_binary(currency) do
    case {enough_in_balance?(from_user, amount, currency),
          enough_in_balance?(to_user, amount, currency), user_exists?(from_user),
          user_exists?(to_user)} do
      {_, _, false, _} ->
        {:error, :sender_does_not_exist}

      {_, _, _, false} ->
        {:error, :sender_does_not_exist}

      {true, true, _, _} ->
        withdraw(from_user, amount, currency)
        deposit(to_user, amount, currency)

      {false, _, _, _} ->
        {:error, :not_enough_money}

      {_, false, _, _} ->
        {:error, :not_enough_money}
    end
  end

  def send(_, _, _), do: {:error, :wrong_arguments}

  ## GenServer Callbacks

  @impl true
  def init(name) do
    Logger.info("Starting process #{name}")
    {:ok, @initial_state}
  end

  def handle_call({:deposit, _user, amount, currency}, _from, state) do
    old_balance = state.balance
    converted_amount = convert_by_currency(amount, currency)
    new_balance = old_balance + converted_amount
    {:reply, :deposit, Map.put(state, :balance, new_balance)}
  end

  def handle_call({:withdraw, _user, amount, currency}, _from, state) do
    old_balance = state.balance
    converted_amount = convert_by_currency(amount, currency)
    new_balance = old_balance - converted_amount
    {:reply, :deposit, Map.put(state, :balance, new_balance)}
  end

  @impl true
  def handle_call({:create_user, id}, _from, _) do
    {:reply, :user_created,
     %Bank{
       balance: @default_balance,
       default_currency: @default_currency,
       id: id
     }}
  end

  ## Private Functions
  defp via_tuple(name),
    do: {:via, Registry, {@registry, name}}

  defp convert_by_currency(amount, currency) do
    amount * @conversion_map[currency]
  end

  defp enough_in_balance?(user, amount, currency) do
    {:ok, balance} = Bank.get_balance(user, currency)
    balance >= amount
  end

  defp too_many_requests?() do
    Process.info(self(), :message_queue_len) <= 10
  end

  defp user_exists?(user) do
    Registry.lookup(:bank_registry, user) != []
  end
end

# Unhandled messages
# Robert Virding - Erlang
# Via tuple - Registry
# Might want to add tests
# Monitors

# https://akoutmos.com/post/rate-limiting-with-genservers/#:~:text=right%20into%20things!-,What%20is%20a%20rate%20limiter%3F,a%20given%201%20minute%20window.
