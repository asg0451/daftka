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

```bash
mix deps.get
mix test
```

### Multi-node (Erlang distribution) integration

Requires `curl` and `jq`.

```bash
mix integration
```

