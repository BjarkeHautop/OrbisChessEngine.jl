# CHANGELOG

## Unreleased

### New features

- Added a history heuristic to move ordering.
- Added Principal Variation Search (PVS) and Late Move Reductions (LMR) to the search.
- Added reverse futility pruning and futility pruning, cutting unpromising nodes/moves at shallow search depth.
- Added mobility and king-safety terms to the evaluation function.
- Added a working UCI implementation (`run_uci()`, launched via `julia --project=. bin/orbis_uci.jl`), supporting `position` and `go` with `depth`, `movetime`, and `wtime`/`btime` time control. `go infinite`/`stop` don't yet interrupt an in-progress search.
- Added a MakieExtension: `plot` now renders a `Makie.Figure` when a Makie backend plus `FileIO` and `Images` are loaded, and falls back to the terminal renderer otherwise.

### Bug fixes

- Fixed `Move(board, str)` always inferring the *black* promotion piece regardless of which side was actually promoting.
- Fixed a dead condition in move ordering's check bonus that meant it never actually applied.
- Fixed mate scores in the transposition table not being adjusted by ply, which could corrupt search scores via transposition; null-move pruning, previously disabled because of this, is re-enabled.
- Fixed `search`/`search_root` returning no move at all (rather than any legal move) when asked to move from a position that's already a draw by insufficient material, threefold repetition, or the fifty-move rule — a UCI tournament manager treats "no move" as an illegal-move forfeit, unlike the legitimate no-legal-moves case (checkmate/stalemate). Found via a self-play game reaching a K+N vs K+B endgame.

## [0.3.0] - 2026-05-07

### Breaking Changes

- Renamed `make_timed_move!` function to `engine_move!`.

- Renamed `plot_board()` to `plot()` and the plotting now plots in the terminal instead of using Makie. The colours used for plotting the board can be changed with Preferences.jl, and it contains a theme for light and dark mode.

### New features

- Added `apply_moves` and `apply_moves!` functions to make several moves in a row (user QOL change).

## Bug fixes

Fixed a bug in the engine causing the evals (and hence moves) to be off.

## [0.2.1] - 2025-11-15

### Changes

- Renamed the old `display` function to `plot_board` for clarity in plotting boards.
- Added `show` method for `Board` and `Game`, providing a simple ASCII representation.

### Improvements

- Small speed improvements.

## [0.2.0] - 2025-10-19

### Breaking Changes

- Renamed `game_over` function to `game_status`

### Improvements

- Major performance improvements: `perft` and `search` are now roughly 10 times faster.
- General code cleanup and internal optimizations.
- Added more tests and fixed several minor bugs.
