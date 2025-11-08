import FileIO: load
import Images: rotr90
import CairoMakie: Figure, Axis, poly!, image!, Rect, hidespines!, DataAspect, RGB

# Path relative to this source file
const ASSET_DIR = abspath(joinpath(@__DIR__, "..", "assets"))

# Piece images used under CC BY-SA 3.0 license:
# Original source: https://commons.wikimedia.org/wiki/Category:PNG_chess_pieces/Standard_transparent
# License: https://creativecommons.org/licenses/by-sa/3.0/
# Changes: none

const PIECE_IMAGES = Dict(
    Piece.W_PAWN => joinpath(ASSET_DIR, "w_pawn.png"),
    Piece.W_KNIGHT => joinpath(ASSET_DIR, "w_knight.png"),
    Piece.W_BISHOP => joinpath(ASSET_DIR, "w_bishop.png"),
    Piece.W_ROOK => joinpath(ASSET_DIR, "w_rook.png"),
    Piece.W_QUEEN => joinpath(ASSET_DIR, "w_queen.png"),
    Piece.W_KING => joinpath(ASSET_DIR, "w_king.png"),
    Piece.B_PAWN => joinpath(ASSET_DIR, "b_pawn.png"),
    Piece.B_KNIGHT => joinpath(ASSET_DIR, "b_knight.png"),
    Piece.B_BISHOP => joinpath(ASSET_DIR, "b_bishop.png"),
    Piece.B_ROOK => joinpath(ASSET_DIR, "b_rook.png"),
    Piece.B_QUEEN => joinpath(ASSET_DIR, "b_queen.png"),
    Piece.B_KING => joinpath(ASSET_DIR, "b_king.png")
)

# (rotr90 to rotate images to match board orientation with rank 1 at bottom)
const PIECE_PIXELS = Dict(k => rotr90(load(v)) for (k, v) in PIECE_IMAGES)

"""
    plot_board(board::Board) -> Makie.Figure

Plot the chess board and pieces using Makie.jl
- `board`: Board struct
"""
function plot_board(board::Board)
    fig = Figure(size = (600, 600))
    ax = Axis(fig[1, 1]; aspect = DataAspect())

    ax.xticks = (collect(0.5:1:7.5), ["a", "b", "c", "d", "e", "f", "g", "h"])
    ax.yticks = (collect(0.5:1:7.5), ["1", "2", "3", "4", "5", "6", "7", "8"])

    light, dark = RGB(0.93, 0.81, 0.65), RGB(0.62, 0.44, 0.27)

    for rank in 1:8, file in 1:8
        color = isodd(rank + file) ? dark : light
        poly!(ax, Rect(file - 1, rank - 1, 1, 1); color = color)
    end

    for (ptype, bb) in enumerate(board.bitboards)
        for sq in 0:63
            if testbit(bb, sq)
                file = (sq % 8) + 1
                rank = (sq ÷ 8) + 1
                image!(ax, (file - 1, file), (rank - 1, rank), PIECE_PIXELS[ptype])
            end
        end
    end

    hidespines!(ax)
    fig
end

"""
    plot_board(game::Game) -> Makie.Figure

Plot the chess board and pieces using Makie.jl
- `game`: Game struct
"""
function plot_board(game::Game)
    return plot_board(game.board)
end

import Base: show

const PIECE_CHARS = Dict(
    Piece.W_PAWN => 'P',
    Piece.W_KNIGHT => 'N',
    Piece.W_BISHOP => 'B',
    Piece.W_ROOK => 'R',
    Piece.W_QUEEN => 'Q',
    Piece.W_KING => 'K',
    Piece.B_PAWN => 'p',
    Piece.B_KNIGHT => 'n',
    Piece.B_BISHOP => 'b',
    Piece.B_ROOK => 'r',
    Piece.B_QUEEN => 'q',
    Piece.B_KING => 'k'
)

"""
    Base.show(io::IO, board::Board)

Display a simple ASCII representation of the given `Board` in the terminal.

Each square shows either a piece or a dot `.` for empty squares. Piece symbols:

- White: `P` (pawn), `N` (knight), `B` (bishop), `R` (rook), `Q` (queen), `K` (king)
- Black: `p` (pawn), `n` (knight), `b` (bishop), `r` (rook), `q` (queen), `k` (king)

The board is printed with rank 8 at the top and file `a` on the left.

# Example

```julia
b = Board() # prints the initial chess position
```
"""
function Base.show(io::IO, board::Board)
    for rank in 7:-1:0
        for file in 0:7
            sq = rank * 8 + file
            piece_char = '.'
            for (ptype, bb) in enumerate(board.bitboards)
                if testbit(bb, sq)
                    piece_char = PIECE_CHARS[ptype]
                    break
                end
            end
            print(io, piece_char, " ")
        end
        println(io)
    end
end

"""
    Base.show(io::IO, game::Game)

Display a simple ASCII representation of the given `Board` in the terminal.

Each square shows either a piece or a dot `.` for empty squares. Piece symbols:

- White: `P` (pawn), `N` (knight), `B` (bishop), `R` (rook), `Q` (queen), `K` (king)
- Black: `p` (pawn), `n` (knight), `b` (bishop), `r` (rook), `q` (queen), `k` (king)

The board is printed with rank 8 at the top and file `a` on the left.

# Example

```julia
g = Game() # prints the initial chess position
```
"""
function Base.show(io::IO, game::Game)
    show(io, game.board)
end
