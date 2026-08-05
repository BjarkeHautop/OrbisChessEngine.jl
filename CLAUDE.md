# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

OrbisChessEngine.jl is a Julia package that implements chess from scratch (bitboard-based move
generation/execution, FEN parsing, game-end detection) plus a chess engine called **Orbis**
(alpha-beta search with iterative deepening, quiescence search, transposition tables, and move
ordering heuristics) and a UCI protocol frontend.

## Commands

Run all commands from the repo root with `--project=.`.

```bash
# Instantiate dependencies (first time / after Project.toml changes)
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Run the full test suite
julia --project=. -e 'using Pkg; Pkg.test()'

# Run a single test file directly (fast inner loop while iterating; note --project=.,
# not --project=test — the test env's Manifest.toml doesn't dev-path in the package itself)
julia --project=. -e 'using OrbisChessEngine, Test; include("test/test-search.jl")'

# Format code (required before committing; CI's pre-commit hook checks this)
julia --project=. -e 'using JuliaFormatter; format(".")'

# Run the UCI engine as a subprocess (e.g. for cutechess-cli or a UCI GUI)
julia --project=. bin/orbis_uci.jl

# Build docs locally
julia --project=docs docs/make.jl
```

Linting/formatting/link-checking also runs via `pre-commit` (see `.pre-commit-config.yaml`) and is
enforced in CI (`.github/workflows/Lint.yml`); Julia code style is `sciml` (`.JuliaFormatter.toml`).
`test/test-aqua.jl` runs `Aqua.test_all` (ambiguities, undefined exports, stale deps, etc.) as part
of the normal test suite.

### Test file convention

Do **not** add tests to `test/runtests.jl`. Instead add a new file named `test/test-title-of-my-test.jl`.
`runtests.jl` walks the `test/` directory, auto-discovers every `test-*.jl` file, and wraps each in a
`@testset` titled from the filename (e.g. `test-move-helpers.jl` → "Move Helpers").

## Architecture

### Module structure

Everything lives in the single module `OrbisChessEngine` (`src/OrbisChessEngine.jl`), which just
`include`s files in dependency order — there are no submodules. When adding new source files,
add the `include` in the right position in that list (types/bit-helpers/zobrist/fen before
board helpers, before move generation, before move execution, before evaluate/search). Read
`src/OrbisChessEngine.jl` first to see the include order and the full public API surface (the
`export` list at the bottom is the contract other code should rely on).

Rough layers, in load order:

1. **Core types** (`src/chess_core/types.jl`, `move.jl`, `bit_helpers.jl`, `zobrist.jl`, `fen.jl`)
   — `Board` (mutable, bitboard-per-piece-type via `MVector{12,UInt64}`, plus a fixed-size
   `undo_stack`/`position_history` sized to `MAX_MOVES_PER_GAME = 512` for allocation-free
   make/undo and threefold-repetition checks), `Move` (immutable, `from`/`to`/`promotion`/
   `capture`/`castling`/`en_passant`), and `Piece` (a `NamedTuple` of piece-type integer
   constants, e.g. `Piece.W_PAWN`).
2. **Board helpers** (`src/chess_core/board_helpers.jl`) and **opening book**
   (`src/opening_book.jl`, `src/polyglot.jl`) — Polyglot `.bin` book format support; a bundled
   Komodo book (`assets/komodo.bin`) is loaded as `KOMODO_OPENING_BOOK` and used by default.
3. **Game state** (`src/chess_core/game.jl`) — `Game` struct (board + per-side clocks), time
   management, and `game_status` (checkmate/stalemate/draw/timeout detection).
4. **Move generation** (`src/chess_core/move_generation/`) — per-piece-type pseudo-legal
   generators (`pawn_moves.jl`, `knight_moves.jl`, `king_moves.jl`, `sliding_moves.jl`) plus
   `legal_moves.jl`, which filters pseudo-legal moves to legal ones. Magic-bitboard bishop
   move generation exists (`magic_bishop.jl`, `magic_numbers.jl`, `perft_bishop_magic`) but is
   **not used by the default move generator / search** — benchmarking showed negligible gains
   (see `docs/src/40-benchmarks.md`).
5. **Move execution** (`src/chess_core/move_execution/`) — `make_move!`/`undo_move!`, which push/pop
   `UndoInfo` on `board.undo_stack` and incrementally update the Zobrist hash and cached eval score.
6. **Evaluation** (`src/piece_square_tables.jl`, `src/evaluate.jl`) — piece-square-table-based
   static evaluation, always from **White's point of view** (search negates/compares based on
   `side_to_move`).
7. **Search** (`src/searchj.jl`) — root iterative-deepening driver (`search_root`) over `_search`
   (alpha-beta + quiescence + null-move pruning), a fixed-size global transposition table
   (`TRANSPOSITION_TABLE`, `1<<20` entries), killer-move ordering, and MVV-LVA capture ordering.
   `search_root` supports a soft (`opt_stop_time`) and hard (`max_stop_time`) time bound: once the
   soft bound is reached it normally stops after the current depth finishes, but extends toward the
   hard bound if the result looks unstable (score dropped, or the best move changed, vs. the
   previous depth — see `PANIC_SCORE_DROP`). `search` (in `searchj.jl`, fixed depth or
   `time_budget`/`max_time_budget`) and `search_with_time` (in `chess_core/game.jl`, time-managed
   via a `Game`'s clocks and `time_management`, which now also accounts for `movestogo`) are the
   public entry points; `engine_move!`/`engine_move` wrap `search_with_time` + making the move on a
   `Game`.
8. **UCI** (`src/uci/uci.jl`, `uci_helpers.jl`, entry point `bin/orbis_uci.jl`) — a synchronous
   command loop (`position`, `go` with `depth`/`movetime`/`wtime`+`btime`+`movestogo`). `go
   infinite`/`stop` do not interrupt an in-progress search since search isn't cancellable mid-flight.
9. **UI** (`src/ui.jl` + weak dependency `ext/OrbisChessEngineMakieExt.jl`) — `plot()` renders in
   the terminal by default; if a Makie backend + `FileIO` + `Images` are loaded, it dispatches to
   `plot_makie` for a graphical `Figure` instead (loaded via a package extension, not a hard dep).

### Search correctness invariants (previously-fixed bugs, don't reintroduce)

Two related bugs used to corrupt search results; both are fixed, but the fixes are easy to
accidentally undo when touching `_search`/`search_root`, so the invariants are worth knowing:

- **Mate score TT ply adjustment.** `tt_probe`/`tt_store` in `src/searchj.jl` store/return mate
  scores (`±(MATE_VALUE - ply)`), which are only meaningful relative to the ply they were computed
  at. `mate_score_to_tt`/`mate_score_from_tt` re-anchor them to the position itself before storing
  and back to the current search's root on retrieval, so a value cached at one ply is safe to reuse
  via a transposition hit at a *different* ply. This is what let null-move pruning be re-enabled —
  it was previously disabled because its reduced-depth subtrees transposed into mate-adjacent
  scores often enough to surface this bug constantly. If you touch `tt_probe`/`tt_store`, keep
  routing mate-range scores through these two functions.
- **`SearchResult.complete`.** A node cut short mid-loop by the time budget must never be mistaken
  for a fully-compared minimax value — `complete` is `false` for such nodes, `_search` immediately
  propagates a `!complete` child result upward instead of comparing it, and `search_root` only
  adopts a depth's result once it's `complete`. Without this, a depth that only got through a
  handful of root moves before timing out could silently overwrite a fully-compared shallower
  depth's answer with an unrefuted (and possibly losing) move — this is exactly what caused a real
  game loss that motivated the fix; see the regression tests in `test/test-search.jl` for both bugs.

### Performance-sensitive code paths

`perft`, `_search`, and `quiescence` are hot paths and deliberately avoid allocation: move lists
are pre-allocated `MVector{MAX_MOVES,Move}` buffers indexed by ply/depth (`moves_stack`,
`pseudo_stack`, `score_stack`), not freshly allocated per call. When touching these functions,
preserve that pattern — don't reintroduce per-node allocations (e.g. `push!`-ing to a `Vector`
inside the recursive search/perft loop). `@inbounds`/`@inline` are used deliberately in these
paths; keep them when refactoring nearby code, and check `docs/src/40-benchmarks.md` before/after
perf-sensitive changes.
