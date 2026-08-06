# [Getting Started: Playing via UCI](@id uci_guide)

Orbis also speaks a subset of the [UCI](https://en.wikipedia.org/wiki/Universal_Chess_Interface)
protocol, so it can be driven by a UCI-speaking GUI or a tournament manager like
[cutechess-cli](https://github.com/cutechess/cutechess). Useful for playing
against other engines.

## Launching Orbis as a UCI engine

Use the [`run_uci`](@ref) function which starts a synchronous command loop over stdin/stdout, as UCI expects.

## Supported commands

- `uci` / `isready` / `ucinewgame`: standard handshake.
- `position startpos moves ...` / `position fen <fen> moves ...`: set up a position,
  optionally followed by a sequence of moves in long algebraic notation.
- `go depth <n>`: search to a fixed depth.
- `go movetime <ms>`: search for a fixed number of milliseconds.
- `go wtime <ms> btime <ms> [winc <ms> binc <ms>] [movestogo <n>]`: search using the
  clock/increment (and `movestogo`, if provided) to decide how long to think, the same
  time management used by [`engine_move!`](@ref) for a [`Game`](@ref).
- `stop` / `quit`.

`go infinite`/`stop` do not yet interrupt an in-progress search. Search currently runs
synchronously to completion rather than in a cancellable background task, so `stop` only
takes effect once the current search finishes on its own.

## Using it with cutechess-cli

To play Orbis against another UCI engine (e.g. Stockfish), or against a previous version
of itself, you can for instance use [cutechess-cli](https://github.com/cutechess/cutechess) as the match manager.

### Playing against Stockfish

From the root of this repository, run the following
to run 40 games of 1/sec against Stockfish adjusted
to 1800 Elo, 5 games running in parallel (each engine
uses its own thread per game, so 10 threads total).

```bash
cutechess-cli \
  -engine name=Orbis cmd=julia arg="--project=." arg="bin/orbis_uci.jl" dir=. proto=uci \
  -engine name=Stockfish cmd=stockfish proto=uci option.UCI_LimitStrength=true option.UCI_Elo=1800 \
  -each st=1 timemargin=500 \
  -rounds 40 \
  -concurrency 5 \
  -pgnout results.pgn
```

## A/B-testing a specific change with self-play

The easiest way to get two independent copies of the engine to play each other is a
[git worktree](https://git-scm.com/docs/git-worktree), checked out at the commit
*before* your change.

```bash
git worktree add ../orbis-baseline <baseline-commit-or-tag>
```

Then run both as separate `cutechess-cli` engines:

```bash
cutechess-cli \
  -engine name=New cmd=julia arg="--project=." arg="bin/orbis_uci.jl" dir=. proto=uci \
  -engine name=Baseline cmd=julia arg="--project=." arg="bin/orbis_uci.jl" dir=../orbis-baseline proto=uci \
  -each st=1 timemargin=500 \
  -rounds 200 -repeat \
  -concurrency 5 \
  -sprt elo0=0 elo1=10 alpha=0.05 beta=0.05 \
  -pgnout selfplay.pgn
```

`-sprt elo0=0 elo1=10 alpha=0.05 beta=0.05` runs a
[Sequential Probability Ratio Test](https://www.chessprogramming.org/Sequential_Probability_Ratio_Test):
`cutechess-cli` stops the match on its own once there's enough evidence for or against
"New is at least 10 Elo stronger than Baseline".

Clean up the worktree afterwards with:

```bash
git worktree remove ../orbis-baseline
```
