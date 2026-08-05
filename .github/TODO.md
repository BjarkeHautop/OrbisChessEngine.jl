## TODO

### Search

- Fix mate-score handling in the transposition table (`tt_probe`/`tt_store` in `searchj.jl` don't adjust scores by ply, so a mate score cached at one ply can be reused via transposition at a different ply and corrupt the score) and re-enable null-move pruning, which is disabled because it surfaces this

- Improve search performance by minimizing allocations

- Add Late Move Reductions (LMR).

- Add Principal Variation Search (PVS).

- Improve move ordering heuristics.

### Evaluation

- Improve evaluation function (e.g. add pawn structure, king safety, trapped pieces, etc.)

### Move generation

- Add magic bitboards for faster move generation (added for bishops, but not yet used. Minimal performance improvement observed - see [Benchmarks](https://bjarkehautop.github.io/OrbisChessEngine.jl/dev/40-benchmarks/) for details.)

### QOL

- Support live-cancellable search (`go infinite` / `stop`) in the [UCI](https://en.wikipedia.org/wiki/Universal_Chess_Interface) implementation, for pondering.

- Make executable with [PackageCompiler.jl](https://julialang.github.io/PackageCompiler.jl/dev/).

- Implement into Lichess bot (see <https://github.com/lichess-bot-devs/lichess-bot>)

### Multi-threaded

- Add support for multiple threads in search (e.g. lazy SMP)
