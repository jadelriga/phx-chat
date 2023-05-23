defmodule Chat.GenServers.RoomManager do
  use GenServer

  # Client side
  def start(room_name) do
    GenServer.start(__MODULE__, nil, name: String.to_atom(room_name))
  end

  def subscribe(room_name, username) do
    GenServer.call(String.to_existing_atom(room_name), {:subscribe, username})
  end

  def create_private_room(current_room, new_room, dest, user2) do
    GenServer.call(String.to_existing_atom(current_room), {:private_room, new_room, dest, user2})
  end

  def send_message(room_name, message, sender) do
    GenServer.call(
      String.to_existing_atom(room_name),
      {:send_message, message, sender}
    )
  end

  # Server side
  @impl GenServer
  def init(_) do
    state = %{
      subscriptions: [],
      messages: [],
      recipients: []
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:report_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:subscribe, username}, {pid, _rest}, %{subscriptions: users} = state) do
    new_state = %{state | subscriptions: update_list_helper(username, pid, users)}
    publish_users(new_state)
    {:reply, filter_state(new_state), new_state}
  end

  def handle_call(
        {:send_message, message, sender},
        _from,
        %{messages: messages, recipients: recipients} = state
      ) do
    new_state = %{state | messages: [{message, sender} | messages]}
    publish_messages(new_state)
    if length(recipients) != 0, do: publish_direct_messages(new_state, sender), else: nil
    {:reply, filter_state(new_state), new_state}
  end

  def handle_call(
        {:private_room, room_name, dest, user2},
        _from,
        %{subscriptions: users} = state
      ) do
    recipients = Enum.filter(users, fn user -> user.name == dest end)
    GenServer.start(__MODULE__, nil, name: String.to_atom(room_name))
    GenServer.call(String.to_existing_atom(room_name), {:add_recipient, recipients})
    response = subscribe(room_name, user2)
    {:reply, response, state}
  end

  def handle_call(
        {:add_recipient, recipients},
        _from,
        state
      ) do
    new_state = Kernel.put_in(state, [:recipients], state.recipients ++ recipients)
    {:reply, filter_state(new_state), new_state}
  end

  defp filter_state(%{subscriptions: users} = state) do
    state
    |> Map.put(:users, get_all_usernames(users))
    |> Map.drop([:subscriptions, :recipients])
  end

  defp publish(list, message) do
    Enum.each(list, fn pid -> send(pid, message) end)
  end

  defp publish_messages(%{subscriptions: users, messages: messages}) do
    publish(get_all_pids(users), {:messages, messages})
  end

  defp publish_direct_messages(%{recipients: recipients}, sender) do
    dest = Enum.filter(recipients, fn user -> user.name != sender end)
    publish(get_all_pids(dest), {:direct_message, sender})
  end

  defp publish_users(%{subscriptions: users}) do
    publish(
      get_all_pids(users),
      {:users, get_all_usernames(users)}
    )
  end

  defp get_all_usernames(users) do
    Enum.map(users, fn user -> user.name end)
  end

  defp get_all_pids(users) do
    Enum.reduce(users, [], fn user, acc -> user.pids ++ acc end)
  end

  defp update_list_helper(name, pid, []) do
    [%{name: name, pids: [pid]}]
  end

  defp update_list_helper(name, pid, [%{name: name, pids: pids} | tail]) do
    [%{name: name, pids: [pid | pids]} | tail]
  end

  defp update_list_helper(name, pid, [head | tail]) do
    [head | update_list_helper(name, pid, tail)]
  end
end
