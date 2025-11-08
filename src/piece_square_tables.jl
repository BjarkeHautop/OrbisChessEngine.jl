# Tables given from white's perspective to make it easier to read and maintain. So, upper left (PAWN_TABLE[1]) is A8, and upper right (PAWN_TABLE[64]) is H1.
# For black pieces, the table is mirrored.

# Inspired by https://rustic-chess.org/evaluation/psqt.html

const PAWN_TABLE_W = [
    100, 100, 100, 100, 100, 100, 100, 100,
    150, 150, 150, 150, 150, 150, 150, 150,
    140, 140, 140, 140, 140, 140, 140, 140,
    120, 120, 120, 130, 130, 120, 120, 120,
    105, 105, 115, 120, 120, 105, 105, 105,
    105, 105, 105, 125, 125, 100, 105, 105,
    105, 105, 105, 70, 70, 110, 110, 110,
    100, 100, 100, 100, 100, 100, 100, 100
]

const PAWN_TABLE_BD = [
    100, 100, 100, 100, 100, 100, 100, 100,
    105, 105, 105, 70, 70, 110, 110, 110,
    105, 105, 105, 125, 125, 100, 105, 105,
    105, 105, 115, 120, 120, 105, 105, 105,
    120, 120, 120, 130, 130, 120, 120, 120,
    140, 140, 140, 140, 140, 140, 140, 140,
    150, 150, 150, 150, 150, 150, 150, 150,
    100, 100, 100, 100, 100, 100, 100, 100
]

const KNIGHT_TABLE_W = [
    290, 300, 300, 300, 300, 300, 300, 290,
    300, 305, 305, 305, 305, 305, 305, 300,
    300, 305, 320, 320, 320, 320, 305, 300,
    300, 305, 320, 330, 330, 320, 305, 300,
    300, 305, 320, 330, 330, 320, 305, 300,
    300, 305, 320, 320, 320, 320, 305, 300,
    300, 305, 305, 305, 305, 305, 305, 300,
    290, 310, 300, 300, 300, 300, 310, 290
]

const BISHOP_TABLE_W = [
    300, 320, 320, 320, 320, 320, 320, 300,
    310, 320, 320, 320, 320, 320, 320, 310,
    310, 320, 330, 330, 330, 330, 320, 310,
    310, 330, 330, 340, 340, 330, 330, 310,
    325, 325, 330, 340, 340, 330, 325, 325,
    310, 325, 330, 330, 330, 330, 325, 310,
    310, 325, 325, 330, 330, 325, 325, 310,
    300, 310, 310, 310, 310, 310, 310, 300
]

const ROOK_TABLE_W = [
    500, 500, 500, 500, 500, 500, 500, 500,
    515, 515, 515, 520, 520, 515, 515, 515,
    500, 500, 500, 500, 500, 500, 500, 500,
    500, 500, 500, 500, 500, 500, 500, 500,
    500, 500, 500, 500, 500, 500, 500, 500,
    500, 500, 500, 500, 500, 500, 500, 500,
    500, 500, 500, 500, 500, 500, 500, 500,
    500, 500, 500, 510, 510, 510, 500, 500
]

# Make queen table for opening also so it doesn't move
# queen in opening
const QUEEN_TABLE_W = [
    910, 920, 930, 930, 930, 930, 920, 910,
    920, 930, 935, 935, 935, 935, 930, 920,
    930, 935, 940, 940, 940, 940, 935, 930,
    930, 935, 940, 945, 945, 940, 935, 930,
    930, 935, 940, 945, 945, 940, 935, 930,
    920, 930, 935, 935, 935, 935, 930, 920,
    920, 930, 935, 935, 935, 935, 930, 920,
    910, 920, 930, 930, 930, 930, 920, 910
]

const KING_TABLE_W = [
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, -10, -10, 0, 0, 0,
    0, 10, 20, -10, -10, 0, 20, 0
]

const KING_TABLE_END_W = [
    -100, -90, -90, -90, -90, -90, -90, -100,
    -90, -50, -50, -50, -50, -50, -50, -90,
    -90, -50, -20, -20, -20, -20, -50, -90,
    -90, -50, -20, 0, 0, -20, -50, -90,
    -90, -50, -20, 0, 0, -20, -50, -90,
    -90, -50, -20, -20, -20, -20, -50, -90,
    -90, -50, -50, -50, -50, -50, -50, -90,
    -100, -90, -90, -90, -90, -90, -90, -100
]

# Flip index vertically (mirror ranks only)
flip_index(idx) = begin
    i0 = idx - 1
    file = mod(i0, 8)
    rank_top = div(i0, 8)
    mirrored = (7 - rank_top) * 8 + file + 1
    return mirrored
end

# Convert 0-based square (a1=0..h8=63) to PSQT index (1-based, A8=1..H1=64)
psqt_index(square) = 8 * (7 - div(square, 8)) + mod(square, 8) + 1

"""
Flip a piece-square table vertically (white → black perspective).
Input is a 64-element vector (row-major, starting at A8).
Returns a new 64-element vector with ranks mirrored.
"""
function flip_table(tbl)
    flipped = similar(tbl)
    for rank in 0:7
        for file in 0:7
            src = rank * 8 + file + 1        # source index (1-based)
            dst = (7 - rank) * 8 + file + 1  # mirrored rank, same file
            flipped[dst] = tbl[src]
        end
    end
    return flipped
end

const PAWN_TABLE_B = flip_table(PAWN_TABLE_W)
const KNIGHT_TABLE_B = flip_table(KNIGHT_TABLE_W)
const BISHOP_TABLE_B = flip_table(BISHOP_TABLE_W)
const ROOK_TABLE_B = flip_table(ROOK_TABLE_W)
const QUEEN_TABLE_B = flip_table(QUEEN_TABLE_W)
const KING_TABLE_B = flip_table(KING_TABLE_W)
const KING_TABLE_END_B = flip_table(KING_TABLE_END_W)

const PIECE_TABLES = [
    PAWN_TABLE_W,
    KNIGHT_TABLE_W,
    BISHOP_TABLE_W,
    ROOK_TABLE_W,
    QUEEN_TABLE_W,
    KING_TABLE_W,
    PAWN_TABLE_B,
    KNIGHT_TABLE_B,
    BISHOP_TABLE_B,
    ROOK_TABLE_B,
    QUEEN_TABLE_B,
    KING_TABLE_B
]

const MAX_PHASE = 24

function is_black(piece)
    return piece >= 7
end

"""
Return the PSQT value of a piece on a given square.
- piece: Piece.W_PAWN..Piece.B_KING
- square: 0..63 (a1=0, h8=63)
- phase: Int (0..MAX_PHASE)
"""
@inline function piece_square_value(piece, square, phase)
    idx = psqt_index(square)
    t = PIECE_TABLES[piece]

    if piece == Piece.W_KING
        open = t[idx]
        endg = KING_TABLE_END_W[idx]
        return ((phase * open + (MAX_PHASE - phase) * endg) ÷ MAX_PHASE)
    elseif piece == Piece.B_KING
        open = t[idx]
        endg = KING_TABLE_END_B[idx]
        return -((phase * open + (MAX_PHASE - phase) * endg) ÷ MAX_PHASE)
    elseif is_black(piece)
        return -t[idx]
    else
        return t[idx]
    end
end

sum(OrbisChessEngine.PIECE_TABLES[1])
