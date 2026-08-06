# [Getting Started: Playing Interactively](@id quick_guide)

This guide covers using OrbisChessEngine as a Julia package — creating positions,
making moves, and calling the engine directly from Julia code. To use it as a
UCI engine from a GUI or a tool like `cutechess-cli` instead, see the
[UCI guide](@ref uci_guide).

## Playing Chess

First we load the package:

```@example quickguide
using OrbisChessEngine
```

We can create a starting position using:

```@example quickguide
board = Board()
```

or load a game from a FEN string:

```@example quickguide
board = Board(fen="rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
```

This is a struct of type `Board` which contains the relevant information about the chess position needed for playing and searching. It provides a simple ASCII `show` method, but you can use `plot` instead, as shown below.

### Graphical rendering

To view the board we can use `plot()`:

```@example quickguide
plot(board)
```

`plot` prints a colored board to the terminal by default, using a dark theme. If your editor/terminal
uses a light theme, switch the board to match by setting the `"theme"` preference (via
[Preferences.jl](https://github.com/JuliaPackaging/Preferences.jl)) to `"light"`:

```julia
using Preferences
set_preferences!(OrbisChessEngine, "theme" => "light")
```

If a Makie backend (e.g. `CairoMakie`) plus `FileIO` and `Images` are loaded, `plot`
returns a graphical `Figure` instead.

```@example quickguide
import CairoMakie, FileIO, Images
plot(board)
```

## Making Moves

We can use `Move` to create a move. Several formats are supported, but the simplest is
to use the long algebraic notation:

```@example quickguide
mv = Move(board, "e2e4")
```

The advantage of the move format used above, is that you don't have to specify captures, promotions or castling, as these are inferred from the board position (hence it needs the board as an argument).

We can make a move using by `make_move()` or the in-place version `make_move!()`:

```@example quickguide
make_move!(board, mv)
```

We can undo a move using `undo_move()` or the in-place version `undo_move!()`:

```@example quickguide
undo_move!(board, mv)
```

Note that `make_move()` (and the in-place version `make_move!()`) does **not** check legality, so it is possible to make illegal moves. To ensure moves are legal, you can use `apply_moves()` (or the in-place version `apply_moves!()`), which will throw an error if any move is illegal.

```@example quickguide
apply_moves!(board, "e2e4", "e7e5", "g1f3", "b8c6", "f1b5")
```

You can check the game status using `game_status()`:

```@example quickguide
game_status(board)
```

## Using the Engine

To generate a move using the engine we can use `search()`:

```@example quickguide
result = search(board; depth = 3, opening_book = nothing)
```

`search()` returns a `SearchResult` object containing the evaluation score, the move and if it is a book move. This package ships with a small opening book, which is default when calling `search()`. To disable the opening book, set `opening_book = nothing`. To use a custom opening book use [`load_polyglot_book()`](@ref) to load another polyglot book in `.bin` format.

To make a 3+2 game we can use `Game()`:

```@example quickguide
game = Game(; minutes = 3, increment = 2)
```

or the short-hand notation:

```@example quickguide
game = Game("3+2")
```

This is a struct of type `Game` which contains the board, white and black time left, and the increment.

The engine will then automatically allocate how much time to use for each move. To let the engine make a move in a timed game we can use `engine_move!()`:

```@example quickguide
engine_move!(game)
```

Combining everything we can let the engine play against itself in a 1+1 game against itself:

```julia
game = Game("1+1")
boards = [deepcopy(game.board)]
while game_status(game.board) == :ongoing
    engine_move!(game)
    push!(boards, deepcopy(game.board))
end
```

And view the game:

```julia
for i in eachindex(boards)
    sleep(0.5)
    plot(boards[i])
end
```
