# [Getting Started: Playing via UCI](@id uci_guide)

Orbis also speaks a subset of the [UCI](https://en.wikipedia.org/wiki/Universal_Chess_Interface)
protocol, so it can be driven by a UCI-speaking GUI or a tournament manager like
[cutechess-cli](https://github.com/cutechess/cutechess). Useful for playing
against other engines.

## Launching Orbis as a UCI engine

From the root of this repository (or point your GUI/tool at this command):

```bash
julia --project=. bin/orbis_uci.jl
```

This starts a synchronous command loop over stdin/stdout, as UCI expects.

## Supported commands

- `uci` / `isready` / `ucinewgame` — standard handshake.
- `position startpos moves ...` / `position fen <fen> moves ...` — set up a position,
  optionally followed by a sequence of moves in long algebraic notation.
- `go depth <n>` — search to a fixed depth.
- `go movetime <ms>` — search for a fixed number of milliseconds.
- `go wtime <ms> btime <ms> [winc <ms> binc <ms>] [movestogo <n>]` — search using the
  clock/increment (and `movestogo`, if provided) to decide how long to think, the same
  time management used by [`engine_move!`](@ref) for a [`Game`](@ref).
- `stop` / `quit`.

`go infinite`/`stop` do not yet interrupt an in-progress search — search currently runs
synchronously to completion rather than in a cancellable background task, so `stop` only
takes effect once the current search finishes on its own.

## Using it with cutechess-cli

To play Orbis against another UCI engine (e.g. Stockfish), or against a previous version
of itself, see the [Benchmarks](@ref benchmarks) page for example `cutechess-cli`
invocations.
