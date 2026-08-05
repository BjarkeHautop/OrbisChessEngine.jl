# CHANGELOG

## Unreleased

### Breaking Changes

- `plot` now renders a graphical `Makie.Figure` when a Makie backend (`CairoMakie`, `GLMakie`, `WGLMakie`, ...) plus `FileIO` and `Images` are loaded, and falls back to the terminal renderer otherwise.

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
