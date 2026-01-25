using Preferences

const DEFAULT_PREFS = (
    theme = "dark", light = (
        light_square_bg = "\e[48;5;230m",
        dark_square_bg = "\e[48;5;110m"
    ),
    dark = (
        light_square_bg = "\e[48;5;235m",
        dark_square_bg = "\e[48;5;238m"
    )
)

function _get_pref(key::Symbol, default)
    @load_preference(String(key), default)
end

function chessboard_colors()
    theme = _get_pref(:theme, DEFAULT_PREFS.theme)

    @assert theme == "light" || theme == "dark" "Invalid theme: $theme"

    defaults = theme == "dark" ? DEFAULT_PREFS.dark : DEFAULT_PREFS.light

    light = _get_pref(
        Symbol(theme * "_light_square_bg"),
        defaults.light_square_bg
    )

    dark = _get_pref(
        Symbol(theme * "_dark_square_bg"),
        defaults.dark_square_bg
    )

    return light, dark, "\e[0m"
end

const PIECE_IMAGES = Dict(
    Piece.W_PAWN => '♟',
    Piece.W_KNIGHT => '♞',
    Piece.W_BISHOP => '♝',
    Piece.W_ROOK => '♜',
    Piece.W_QUEEN => '♛',
    Piece.W_KING => '♚',
    Piece.B_PAWN => '♙',
    Piece.B_KNIGHT => '♘',
    Piece.B_BISHOP => '♗',
    Piece.B_ROOK => '♖',
    Piece.B_QUEEN => '♕',
    Piece.B_KING => '♔'
)

function piece_glyph(ptype::Int, theme::String)
    p = ptype

    if theme == "light"
        # Hack: piece colors looks swapped on light theme
        p = p ≤ 6 ? p + 6 : p - 6
    end

    return PIECE_IMAGES[p]
end

"""
    plot(board::Board; board_orientation = :white, io::IO = stdout)
Display a colored chess board in the terminal using Unicode chess piece characters.
- `board`: Board struct
- `board_orientation`: `:white` (default) or `:black` to set the perspective
- `io`: IO stream to print to (default: `stdout`)

# Example
```julia
board = Board()
plot(board)

# Change orientation
plot(board; board_orientation = :black)

# Change plot preference colors
using Preferences
set_preferences!(
    OrbisChessEngine,
    "theme" => "light",
)
plot(board)
```

If you have issues with the piece characters not displaying correctly,
consider using another font. We recommend "DejaVu Sans Mono" available at https://dejavu-fonts.github.io/.
"""
function plot(board::Board; board_orientation = :white, io::IO = stdout)
    light, dark, reset = chessboard_colors()
    theme = _get_pref(:theme, DEFAULT_PREFS.theme)

    if board_orientation === :white
        ranks = 7:-1:0
        files = 0:7
    else
        ranks = 0:7
        files = 7:-1:0
    end

    println(io)

    for r in ranks
        print(io, " ", r + 1, " ")
        for f in files
            sq = r * 8 + f

            piece_image = ' '
            for (ptype, bb) in enumerate(board.bitboards)
                if testbit(bb, sq)
                    piece_image = piece_glyph(ptype, theme)
                    break
                end
            end

            # Chessboard coloring is geometric, not orientation-dependent
            bg = isodd(r + f) ? light : dark
            print(io, bg, " ", piece_image, " ", reset)
        end
        println(io)
    end

    # File labels
    if board_orientation === :white
        println(io, "    a  b  c  d  e  f  g  h")
    else
        println(io, "    h  g  f  e  d  c  b  a")
    end
end

"""
    plot(game::Game; board_orientation = :white, io::IO = stdout)
Display a colored chess board in the terminal using Unicode chess piece characters.
- `game`: Game struct
- `board_orientation`: `:white` (default) or `:black` to set the perspective
- `io`: IO stream to print to (default: `stdout`)

# Example
```julia
game = Game()
plot(game)

# Change orientation
plot(game; board_orientation = :black)

# Change plot preference colors
using Preferences
set_preferences!(
    OrbisChessEngine,
    "theme" => "light",
)
plot(game)
```
"""
function plot(game::Game; board_orientation = :white, io::IO = stdout)
    plot(game.board; board_orientation = board_orientation, io = io)
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

##### Old plotting code

#= ...

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

=#
