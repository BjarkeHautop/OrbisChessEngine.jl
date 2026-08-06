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

Based on 40 games vs Stockfish 1800 Elo 1s/move it scored 21-17-2 (W/L/D) giving an estimate
of 1834.9 ± 108.8 Elo.
