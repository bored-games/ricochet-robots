defmodule RicochetRobots do
  use Application

  def start(_type, _args) do
    children = [
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: RicochetRobots.Router,
        options: [
          dispatch: dispatch(),
          port: 4000
        ]
      ),
      Registry.child_spec(
        keys: :duplicate,
        name: Registry.RicochetRobots
      )
    ]

    opts = [strategy: :one_for_one, name: RicochetRobots.Application]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    [
      {:_,
       [
         {"/ws/[...]", RicochetRobots.SocketHandler, []},
         {:_, Plug.Cowboy.Handler, {RicochetRobots.Router, []}}
       ]}
    ]
  end
end
