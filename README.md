# OrbisChessEngine.jl

[![Stable Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://BjarkeHautop.github.io/OrbisChessEngine.jl/stable)
[![Development documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://BjarkeHautop.github.io/OrbisChessEngine.jl/dev)
[![Test workflow status](https://github.com/BjarkeHautop/OrbisChessEngine.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/BjarkeHautop/OrbisChessEngine.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/BjarkeHautop/OrbisChessEngine.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/BjarkeHautop/OrbisChessEngine.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![SciML Code Style](https://img.shields.io/static/v1?label=code%20style&message=SciML&color=9558b2&labelColor=389826)](https://github.com/SciML/SciMLStyle)
[![BestieTemplate](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/JuliaBesties/BestieTemplate.jl/main/docs/src/assets/badge.json)](https://github.com/JuliaBesties/BestieTemplate.jl)

<p align="center">
  <img src="https://raw.githubusercontent.com/BjarkeHautop/OrbisChessEngine.jl/main/assets/logo.png" alt="Orbis Logo" width="200"/>
</p>

A Julia package that implements chess from scratch alongside a chess engine, **Orbis**. It provides functionalities to represent the chessboard, validate moves, and evaluate positions.
Particularly, *OrbisChessEngine* implements:

- All chess rules
- Bitboard representation
- Legal move generation (tested with [perft](https://www.chessprogramming.org/Perft))
- [FEN](https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation) parsing
- Opening book support
- Minimax search with alpha–beta pruning, iterative deepening, quiescence search, transposition tables, null move pruning, and move ordering heuristics
- Evaluation function based on piece-square tables

## Installation

`OrbisChessEngine` can be installed directly from the Julia package manager.
In the Julia REPL, press `]` to enter the Pkg mode, then run:

```julia
pkg> add OrbisChessEngine
```

## Example

Here we show an example of how to let the engine play a "1+1" game against itself and plot it afterwards to view it.

```julia
game = Game("1+1")
plots = []
while game_status(game.board) == :ongoing
    make_timed_move!(game)
    push!(plots, display(game))
end

for i in eachindex(plots)
    sleep(0.5)
    display(plots[i])
end
```

## Resources

View the documentation at [https://BjarkeHautop.github.io/OrbisChessEngine.jl/dev/](https://BjarkeHautop.github.io/OrbisChessEngine.jl/dev/).

Visit chess programming wiki for useful articles on chess engine programming: [https://www.chessprogramming.org/Main_Page](https://www.chessprogramming.org/Main_Page).

## TODO

- Improve search performance by minimizing allocations

- Improve evaluation function (e.g. add pawn structure, king safety, trapped pieces, etc.)

- Add support for multiple threads in search (e.g. lazy SMP)

- Implement (some of) [UCI](https://en.wikipedia.org/wiki/Universal_Chess_Interface) protocol

- Make executable with [PackageCompiler.jl](https://julialang.github.io/PackageCompiler.jl/dev/)

- Add magic bitboards for faster move generation (added for bishops, but not yet used. Minimal performance improvement observed - see [Benchmarks](https://bjarkehautop.github.io/OrbisChessEngine.jl/dev/40-benchmarks/) for details.)

- Implement into Lichess bot (see <https://github.com/lichess-bot-devs/lichess-bot>)
