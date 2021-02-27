# Ricochet Robots

A multiplayer websocket-based implementation of a backend for Ricochet Robots and other games.

This repository is meant to be paired with a frontend. For a frontend, see
https://github.com/bored-games/robots-client.

## Deployment
Install elixir dependencies by running from the root folder:
`mix deps.get`

A PostgreSQL instance is necessary for storing Ricochet Robot solutions. User/pass credentials must be edited in `config/config.exs`.
The database can be created using `mix ecto.create` and `mix ecto.migrate` which follow the instructions in `priv/repo/migrations`.

To run the server:
`mix run --no-halt` or `iex.bat -S run`

## License

```
Copyright (C) 2019 azuline <azuline@riseup.net>
Copyright (C) 2019 gg314

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
```
