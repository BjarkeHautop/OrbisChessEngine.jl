########################
# Piece type constants #
########################

@enum Side WHITE=0 BLACK=1

opposite(side::Side)::Side = side == WHITE ? BLACK : WHITE

"""
    Piece

Container for chess piece constants. Use `Piece.W_PAWN`, `Piece.B_KING`, etc.
"""

const Piece = (
    W_PAWN = 1,
    W_KNIGHT = 2,
    W_BISHOP = 3,
    W_ROOK = 4,
    W_QUEEN = 5,
    W_KING = 6,
    B_PAWN = 7,
    B_KNIGHT = 8,
    B_BISHOP = 9,
    B_ROOK = 10,
    B_QUEEN = 11,
    B_KING = 12
)

# Convenience: all piece types as a range
const ALL_PIECES = (Piece.W_PAWN):(Piece.B_KING)

const NUM_PIECES = length(ALL_PIECES)

const MAX_MOVES_PER_GAME = 512

#########################
# Board representation  #
#########################
"""
    UndoInfo

Information needed to undo a move

- `captured_piece`: The piece type that was captured, or 0 if none.
- `en_passant`: The previous en passant square.
- `castling_rights`: The previous castling rights.
- `halfmove_clock`: The previous halfmove clock.
- `moved_piece`: The piece type that was moved.
- `promotion`: The piece type if the move was a promotion, or 0 otherwise.
- `is_en_passant`: A boolean indicating if the move was an en passant capture.
- `prev_eval_score`: The evaluation score before the move.
- `prev_game_phase_value`: The game phase value before the move.
"""
struct UndoInfo
    captured_piece::Int
    en_passant::Int
    castling_rights::Int
    halfmove_clock::Int
    moved_piece::Int
    promotion::Int
    is_en_passant::Bool
    prev_eval_score::Int
    prev_game_phase_value::Int
end

using StaticArrays

"""
    Board

A chess board representation using bitboards.

- `bitboards`: A fixed-size vector where each element corresponds to a piece type's bitboard.
- `side_to_move`: The side to move.
- `castling_rights`: A 4-bit integer representing castling rights (KQkq).
- `en_passant`: The square index (0-63) for en passant target, or -1 if none.
- `halfmove_clock`: The number of halfmoves since the last capture or pawn move (for the 50-move rule).
- `position_history`: A vector of position Zobrist hashes for detecting threefold repetition.
- `undo_stack`: A stack of `UndoInfo` structs for unmaking moves.
- `undo_index`: The current index in the undo stack.
- `eval_score`: Cached evaluation score from White's point of view.
- `game_phase_value`: Cached phase numerator (sum of weights) for evaluation scaling.
"""
mutable struct Board
    bitboards::MVector{NUM_PIECES, UInt64} # piece type → bitboard
    side_to_move::Side
    castling_rights::UInt8      # four bits: KQkq
    en_passant::Int8             # square index 0..63, or -1 if none
    halfmove_clock::UInt16          # for 50-move rule
    position_history::MVector{MAX_MOVES_PER_GAME, UInt64}  # for threefold repetition
    undo_stack::MVector{MAX_MOVES_PER_GAME, UndoInfo} # stack of UndoInfo for unmaking moves
    undo_index::Int16         # current index in undo_stack
    eval_score::Int32           # cached evaluation from White’s POV
    game_phase_value::UInt8     # cached phase numerator (sum of weights)
end

function Base.:(==)(a::Board, b::Board)
    if a.bitboards != b.bitboards ||
       a.side_to_move != b.side_to_move ||
       a.castling_rights != b.castling_rights ||
       a.en_passant != b.en_passant ||
       a.halfmove_clock != b.halfmove_clock ||
       a.position_history != b.position_history ||
       a.eval_score != b.eval_score ||
       a.game_phase_value != b.game_phase_value ||
       a.undo_index != b.undo_index
        return false
    end

    for i in 1:(a.undo_index)
        if a.undo_stack[i] != b.undo_stack[i]
            return false
        end
    end

    return true
end

function position_equal(a::Board, b::Board)
    a.bitboards == b.bitboards &&
        a.side_to_move == b.side_to_move &&
        a.castling_rights == b.castling_rights &&
        a.en_passant == b.en_passant &&
        a.halfmove_clock == b.halfmove_clock &&
        a.eval_score == b.eval_score &&
        a.game_phase_value == b.game_phase_value
end
1 + 1
