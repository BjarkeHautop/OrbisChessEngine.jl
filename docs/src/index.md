```@meta
CurrentModule = OrbisChessEngine
```

# OrbisChessEngine

[OrbisChessEngine](https://github.com/BjarkeHautop/OrbisChessEngine.jl) is a chess engine written in Julia. It implements functionality for playing chess and for searching for the best move using the implemented chess engine.

## Installation

`OrbisChessEngine` can be installed directly from the Julia package manager.
In the Julia REPL, press `]` to enter the Pkg mode, then run:

```julia
pkg> add OrbisChessEngine
```

## Features

- All chess rules
- Bitboard representation
- Legal move generation (tested with [perft](https://www.chessprogramming.org/Perft))
- [FEN](https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation) parsing
- Opening book support
- Minimax search with alpha–beta pruning, iterative deepening, quiescence search, transposition tables, null move pruning, and move ordering heuristics
- Evaluation function based on piece-square tables
- Basic [UCI](https://en.wikipedia.org/wiki/Universal_Chess_Interface) protocol support, via `bin/orbis_uci.jl`

## Getting Started

See the [Getting Started](@ref quick_guide) page for installation instructions and basic usage examples
of OrbisChessEngine as a Julia package, or the [UCI guide](@ref uci_guide) to run Orbis as a UCI engine
from a GUI or tool like `cutechess-cli`.
