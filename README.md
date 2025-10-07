# Daftka

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `daftka` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:daftka, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/daftka>.

## Development

- Ensure Erlang/OTP 27 and Elixir 1.18 are installed
- mix deps.get && mix test

### Multi-node (EPMD) quickstart

Run nodes with names and connect via `DAFTKA_CONNECT_TO`:

```bash
elixir --name n1@127.0.0.1 -S mix run --no-halt
DAFTKA_CONNECT_TO=n1@127.0.0.1 elixir --name n2@127.0.0.1 -S mix run --no-halt
```

Configure roles per node via config or env overriding `:daftka, :role`.

