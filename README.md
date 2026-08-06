# OrbisChessEngine.jl

[![Stable Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://BjarkeHautop.github.io/OrbisChessEngine.jl/stable)
[![Development documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://BjarkeHautop.github.io/OrbisChessEngine.jl/dev)
[![Test workflow status](https://github.com/BjarkeHautop/OrbisChessEngine.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/BjarkeHautop/OrbisChessEngine.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/BjarkeHautop/OrbisChessEngine.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/BjarkeHautop/OrbisChessEngine.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![BestieTemplate](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/JuliaBesties/BestieTemplate.jl/main/docs/src/assets/badge.json)](https://github.com/JuliaBesties/BestieTemplate.jl)

A Julia package that implements chess from scratch alongside a chess engine, **Orbis**. It provides functionalities to represent the chessboard, validate moves, and evaluate positions.
Particularly, *OrbisChessEngine* implements:

- All chess rules
- Bitboard representation
- Legal move generation (tested with [perft](https://www.chessprogramming.org/Perft))
- [FEN](https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation) parsing
- Opening book support
- Minimax search with alpha-beta pruning, iterative deepening, quiescence search, transposition tables, null move pruning, and move ordering heuristics
- Evaluation function based on piece-square tables
- Basic [UCI](https://en.wikipedia.org/wiki/Universal_Chess_Interface) protocol support

## Installation

`OrbisChessEngine` can be installed directly from the Julia package manager.
In the Julia REPL, press `]` to enter the Pkg mode, then run:

```julia
pkg> add OrbisChessEngine
```

## Example

Here we show an example of how to let the engine play a "1+1" game against itself and view it move by move afterwards.

```julia
game = Game("1+1")
boards = [deepcopy(game.board)]
while game_status(game.board) == :ongoing
    engine_move!(game)
    push!(boards, deepcopy(game.board))
end

for i in eachindex(boards)
    sleep(0.5)
    plot(boards[i])
end
```

`plot` prints a colored board to the terminal by default. If a Makie backend (e.g. `CairoMakie`) plus `FileIO` and `Images` are loaded it returns a graphical `Figure`
instead.

## Usage as a UCI engine

Orbis also speaks a subset of the [UCI](https://en.wikipedia.org/wiki/Universal_Chess_Interface) protocol, so it can be driven by a UCI-speaking GUI or a tool like `cutechess-cli`. Call `run_uci()` to start the command loop, or point a tool that needs a shell command at `bin/orbis_uci.jl`, a thin wrapper that just calls `run_uci()`:

```bash
julia --project=. bin/orbis_uci.jl
```

See the [UCI guide](https://BjarkeHautop.github.io/OrbisChessEngine.jl/dev/10-uci-guide/) for supported commands.

## Resources

View the documentation at [https://BjarkeHautop.github.io/OrbisChessEngine.jl/dev/](https://BjarkeHautop.github.io/OrbisChessEngine.jl/dev/), including an estimate of Orbis's playing strength and instructions for reproducing it on the "Benchmarks" page.

Visit chess programming wiki for useful articles on chess engine programming: [https://www.chessprogramming.org/Main_Page](https://www.chessprogramming.org/Main_Page).
