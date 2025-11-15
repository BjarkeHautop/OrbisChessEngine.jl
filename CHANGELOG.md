# CHANGELOG

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
