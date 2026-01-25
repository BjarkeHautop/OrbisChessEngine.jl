# [Getting Started](@id quick_guide)

## Installation

`OrbisChessEngine` can be installed directly from the Julia package manager.
In the Julia REPL, press `]` to enter the Pkg mode, then run:

```julia
pkg> add OrbisChessEngine
```

## Playing Chess

First we load the package:

```julia
using OrbisChessEngine
```

We can create a starting position using:

```julia
board = Board()
```

or load a game from a FEN string:

```julia
board = Board(fen="rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
```

This is a struct of type `Board` which contains the relevant information about the chess position needed for playing and searching.

To view the board we can use `plot()`:

```julia
plot(board)
```

If using a light theme editor, you might want to set your preferences to use light theme for the chess board:

```julia
using Preferences
set_preferences!(
    OrbisChessEngine,
    "theme" => "light",
    force = true
)
```

We can use `Move` to create a move. Several formats are supported, but the simplest is
to use the long algebraic notation:

```julia
mv = Move(board, "e2e4")
```

The advantage of the move format used above, is that you don't have to specify captures, promotions or castling, as these are inferred from the board position (hence it needs the board as an argument).

We can make a move using by `make_move()` or the in-place version `make_move!()`:

```julia
make_move!(board, mv)
```

We can undo a move using `undo_move()` or the in-place version `undo_move!()`:

```julia
undo_move!(board, mv)
```

Note that `make_move()` (and the in-place version `make_move!()`) does **not** check legality, so it is possible to make illegal moves. To ensure moves are legal, you can use `apply_move()` (or the in-place version `apply_move!()`), which will throw an error if any move is illegal.

```julia
apply_move!(board, "e2e4", "e7e5", "g1f3", "b8c6", "f1b5")
```

You can check the game status using `game_status()`:

```julia
game_status(board)
```

## Using the Engine

To generate a move using the engine we can use `search()`:

```julia
result = search(board; depth=3, opening_book=nothing)
```

`search()` returns a `SearchResult` object containing the evaluation score, the move and if it is a book move. This package ships with a small opening book, which is default when calling `search()`. To disable the opening book, set `opening_book = nothing`. To use a custom opening book use [`load_polyglot_book()`](@ref) to load another polyglot book in `.bin` format.

To make a 3+2 game we can use `Game()`:

```julia
game = Game(; minutes = 3, increment = 2)
```

or the short-hand notation:

```julia
game = Game("3+2")
```

This is a struct of type `Game` which contains the board, white and black time left, and the increment.

The engine will then automatically allocate how much time to use for each move. To let the engine make a move in a timed game we can use `engine_move!()`:

```julia
engine_move!(game)
```

Combining everything we can let the engine play against itself in a 1+1 game:

```julia
game = Game("1+1")
plots = []
while game_status(game.board) == :ongoing
    engine_move!(game)
    push!(plots, display(game))
end
```

And view the game:

```julia
for i in eachindex(plots)
    sleep(0.5)
    display(plots[i])
end
```
