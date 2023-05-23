defmodule ChatWeb.LobbyLive do
  alias Chat.GenServers.LobbyManager
  use Phoenix.LiveView, layout: {ChatWeb.LayoutView, "live.html"}

  def mount(params, _session, socket) do
    rooms = connect_genserver()
    {:ok, mount_helper(socket, params, rooms)}
  end

  defp mount_helper(socket, %{"username" => username}, rooms) do
    assign(socket, username: username, rooms: rooms)
  end

  defp mount_helper(socket, _username, rooms) do
    assign(socket, username: nil, rooms: rooms)
  end

  defp connect_genserver() do
    LobbyManager.start()
    LobbyManager.subscribe()
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
          height: 400px;
          overflow-y: scroll;
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
      </style>
    </head>
    <body>
      <%= if not is_nil(@username) do%>
        <div class="user-tag">
          <span>Logged in as <%= @username %></span>
        </div>
      <% end %>
      <div class="chat-area" id="chatArea">
        <!-- Messages will be displayed here -->
        <ul>
          <%= for element <- @rooms do %>
          <li><a href={if is_nil(@username), do: "", else: "/rooms/" <> element <> "/" <> @username}><%= element %></a></li>
          <% end %>
        </ul>
      </div>

      <%= if is_nil(@username) do %>
      <form phx-submit="login">
        <div class="form-area flex">
          <input type="text" name="username" id="usernameInput" placeholder="Username" />
          <button class="form-button" type="submit">Login</button>
        </div>
      </form>
      <% else %>
      <form phx-submit="createRoom">
        <div class="form-area flex">
          <input type="text" name="room_name" id="createRoomInput" placeholder="Type the name of the room" />
          <button type="submit" class="form-button">Create</button>
        </div>
      </form>
      <% end %>
    </body>
    </html>
    """
  end

  def handle_event("login", %{"username" => username}, socket) do
    url = "/rooms/" <> username
    {:noreply, redirect(socket, to: url)}
  end

  def handle_event("createRoom", %{"room_name" => room_name}, socket) do
    LobbyManager.create_room(room_name)
    {:noreply, socket}
  end

  def handle_info({:rooms, rooms}, socket) do
    {:noreply, assign(socket, rooms: rooms)}
  end
end
