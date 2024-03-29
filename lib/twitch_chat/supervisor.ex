defmodule TwitchChat.Supervisor do
  @moduledoc """
  TwitchChat is a library for connecting to Twitch chat with Elixir.
  """
  use Supervisor

  @doc """
  Start the TwitchChat supervisor.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    if opts[:start?] == false do
      :ignore
    else
      {bot, opts} = Keyword.pop!(opts, :bot)
      default_name = Module.concat([bot, "BotSupervisor"])
      {name, opts} = Keyword.pop(opts, :name, default_name)

      Supervisor.start_link(__MODULE__, {bot, opts}, name: name)
    end
  end

  @impl true
  def init({bot, opts}) do
    {is_verified, opts} = Keyword.pop(opts, :is_verified, false)
    {mod_channels, opts} = Keyword.pop(opts, :mod_channels, [])

    {:ok, client} = TwitchChat.Client.start_link(Keyword.take(opts, [:debug]))

    conn = build_irc_conn(client, opts)
    msg_server_supervisor = TwitchChat.MessageServer.supervisor_name(bot)

    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: msg_server_supervisor},
      {TwitchChat.ChannelServer, {bot, conn, is_verified, mod_channels}},
      {TwitchChat.ConnectionServer, {bot, conn}},
      {TwitchChat.WhisperServer, {bot, conn}},
      {bot, conn}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp build_irc_conn(client, config) do
    user = Keyword.fetch!(config, :user)
    pass = Keyword.fetch!(config, :pass)
    channels = Keyword.get(config, :channels, [])

    caps =
      config
      |> Keyword.get(:capabilities, [~c"membership", ~c"tags", ~c"commands"])
      |> to_charlist()

    TwitchChat.Conn.new(client, user, pass, channels, caps)
  end
end
