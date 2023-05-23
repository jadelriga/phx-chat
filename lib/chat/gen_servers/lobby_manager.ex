defmodule Chat.GenServers.LobbyManager do
  use GenServer

  # Client side
  def start() do
    GenServer.start(__MODULE__, nil, name: __MODULE__)
  end

  def subscribe() do
    GenServer.call(__MODULE__, :subscribe)
  end

  def create_room(room_name) do
    GenServer.call(__MODULE__, {:create_room, room_name})
  end

  # Server side
  @impl GenServer
  def init(_) do
    state = %{
      subscriptions: [],
      rooms: []
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:subscribe, {pid, _rest}, %{subscriptions: pids} = state) do
    new_state = %{state | subscriptions: [pid | pids]}
    {:reply, new_state.rooms, new_state}
  end

  def handle_call({:create_room, room_name}, _from, %{rooms: rooms} = state) do
    if Enum.any?(rooms, fn room -> room == room_name end) do
      {:reply, {:error, "Room #{room_name} already exists"}, state}
    else
      new_state = %{state | rooms: [room_name | rooms]}
      publish_rooms(new_state)
      {:reply, new_state, new_state}
    end
  end

  defp publish(list, message) do
    Enum.each(list, fn pid -> send(pid, message) end)
  end

  defp publish_rooms(%{subscriptions: pids, rooms: rooms}) do
    publish(pids, {:rooms, rooms})
  end
end
