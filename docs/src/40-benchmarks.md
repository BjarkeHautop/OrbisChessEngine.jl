# [Benchmarks](@id benchmarks)

Starting from version 0.2.0 of OrbisChessEngine this page shows benchmark results for perft for various depths, which can be used to compare performance
with older versions, as well as an estimate of Orbis's playing strength.

## Benchmark Results for Perft

All benchmarks below are using a single thread. Perft uses the `Board` stuct from OrbisChessEngine, which means it computes
zobrist hash, and evaluation score at each node. Thus, it mimics the search process more closely than a pure move generator perft.

```@example
using OrbisChessEngine
using BenchmarkTools
b = Board()
perft(b, 5) # warm up
@benchmark perft($b, 5)
```

Using `perft_bishop_magic` which uses magic bitboards for bishop move generation:

```@example
using OrbisChessEngine
using BenchmarkTools
b = Board()
perft_bishop_magic(b, 5) # warm up
@benchmark perft_bishop_magic($b, 5)
```

Seems to be barely affect performance.

## Playing Strength

We estimate Orbis's playing strength directly
by playing it against [Stockfish](https://stockfishchess.org/) at reduced strength
(via the `UCI_LimitStrength`/`UCI_Elo` options), using
[cutechess-cli](https://github.com/cutechess/cutechess) as the match manager.

Based on 40 games vs Stockfish 1800 ELO it scored 13/40 giving an estimate
of 1692.5 ± 114.7 ELO.

### Steps to Reproduce

1. Install cutechess-cli.
2. Install Stockfish.
3. From the root of this repository, run:

   ```bash
   cutechess-cli \
     -engine name=Orbis cmd=julia arg="--project=." arg="bin/orbis_uci.jl" dir=. proto=uci \
     -engine name=Stockfish cmd=stockfish proto=uci option.UCI_LimitStrength=true option.UCI_Elo=1800 \
     -each st=1 timemargin=500 \
     -rounds 40 -repeat \
     -concurrency 5 \
     -pgnout results.pgn
   ```

   Adjust `option.UCI_Elo` to probe a different strength level, `-rounds` for more/fewer
   games, and `-concurrency` to adjust CPU's core count (each game runs two
   single-threaded processes).

## A/B-testing a specific change with self-play

The easiest way to get two independent copies of the engine to play each other is a
[git worktree](https://git-scm.com/docs/git-worktree), checked out at the commit
*before* your change (e.g. the previous commit, or a release tag):

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
