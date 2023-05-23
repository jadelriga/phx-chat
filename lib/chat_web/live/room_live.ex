defmodule ChatWeb.RoomLive do
  alias Chat.GenServers.RoomManager
  use Phoenix.LiveView, layout: {ChatWeb.LayoutView, "live.html"}

  def mount(params, _session, socket) do
    {:ok, mount_helper(socket, params)}
  end

  defp mount_helper(socket, %{"username" => username, "room_name" => room_name}) do
    state = connect_genserver(room_name, username)

    assign(socket,
      username: username,
      room_name: room_name,
      messages: Enum.reverse(state.messages),
      users: state.users
    )
  end

  defp mount_helper(socket, _) do
    redirect(socket, to: "/room/")
  end

  defp connect_genserver(room_name, username) do
    RoomManager.start(room_name)
    RoomManager.subscribe(room_name, username)
  end

  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html>
    <head>
      <title>Chat App</title>
      <style>
        /* CSS styles for the chat area */
        .chat-area {
          flex: 0 0 75%;
          height: 400px;
          overflow-y: scroll;
          border: 1px solid #ccc;
          padding: 10px;
        }

        .users-area {
          flex: 1; /* Remaining width */
          height: 400px;
          border: 1px solid #ccc;
          padding: 10px;
        }

        /* CSS styles for the login area */
        .form-area {
          margin-top: 20px;
        }

        .flex {
          display: flex;
        }

        .form-button {
          width: 150px;
          margin-left: 10px;
        }

        .user-tag {
          margin-bottom: 2rem;
          text-align: center;
          background-color: lavender;
          border-radius: 10px;
        }

        .pointer:hover {
          cursor:pointer;
        }
      </style>
    </head>
    <h1><%= @room_name %></h1>
    <body>
      <%= if not is_nil(@username) do%>
        <div class="user-tag">
          <span>Logged in as <%= @username %></span>
        </div>
      <% end %>
      <div class="flex">
        <div class="chat-area" id="chatArea">
          <%= for message <- @messages do %>
          <div><span><%= "@#{elem(message, 1)}: #{elem(message, 0)}" %></span></div>
          <% end %>
        </div>
        <div class="users-area" id="usersArea">
          <ul>
            <%= for user <- @users do %>
            <li><a class="pointer" phx-click="openPrivateRoom" phx-value-key={user}><%= user %></a></li>
            <% end %>
          </ul>
        </div>
      </div>

      <form phx-submit="sendMessage">
        <div class="form-area flex">
          <input type="text" name="send_message" id="sendMessageInput" placeholder="Type your message here" />
          <button type="submit" class="form-button">Send</button>
        </div>
      </form>
    </body>
    </html>
    """
  end

  defp get_private_room_url(dest, username, current_room) do
    room_name = if dest < username, do: "#{dest}-#{username}", else: "#{username}-#{dest}"
    {room_name, "/rooms/#{room_name}/#{username}"}
  end

  def handle_event(
        "openPrivateRoom",
        %{"key" => username},
        %{assigns: %{username: username}} = socket
      ) do
    {:noreply, socket |> put_flash(:error, "You cannot send a message to yourself")}
  end

  def handle_event(
        "openPrivateRoom",
        %{"key" => dest},
        %{assigns: %{room_name: current_room, username: username}} = socket
      ) do
    {room_name, url} = get_private_room_url(dest, username, current_room)
    RoomManager.create_private_room(current_room, room_name, dest, username)
    {:noreply, redirect(socket, to: url)}
  end

  def handle_event(
        "sendMessage",
        %{"send_message" => message},
        %{assigns: %{room_name: room_name, username: username}} = socket
      ) do
    RoomManager.send_message(room_name, message, username)

    {:noreply, socket}
  end

  def handle_info({:messages, messages}, socket) do
    {:noreply, assign(socket, messages: Enum.reverse(messages))}
  end

  def handle_info({:users, users}, socket) do
    {:noreply, assign(socket, users: users)}
  end

  def handle_info({:direct_message, username}, socket) do
    {:noreply, socket |> put_flash(:info, "#{username} has sent you a message")}
  end
end
