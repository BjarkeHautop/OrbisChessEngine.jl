# Piece values for move ordering
const PIECE_VALUES = Dict(
    Piece.W_PAWN => 100,
    Piece.B_PAWN => -100,
    Piece.W_KNIGHT => 300,
    Piece.B_KNIGHT => -300,
    Piece.W_BISHOP => 300,
    Piece.B_BISHOP => -300,
    Piece.W_ROOK => 500,
    Piece.B_ROOK => -500,
    Piece.W_QUEEN => 1000,
    Piece.B_QUEEN => -1000,
    Piece.W_KING => 0,
    Piece.B_KING => 0
)

# material weight used for phase calculation
function phase_weight(p)
    (p == Piece.W_QUEEN || p == Piece.B_QUEEN) ? 4 :
    (p == Piece.W_ROOK || p == Piece.B_ROOK) ? 2 :
    (p == Piece.W_BISHOP || p == Piece.B_BISHOP ||
     p == Piece.W_KNIGHT || p == Piece.B_KNIGHT) ? 1 : 0
end

"""
    evaluate(board::Board) -> Int

Evaluate a position from White’s perspective using piece-square tables.
- board: Board struct

# Example
```julia
board = Board()
evaluate(board)
````
"""
function evaluate(board::Board)
    # --- Check for terminal game states ---
    status = game_status(board)
    if status == :checkmate_white
        return MATE_VALUE
    elseif status == :checkmate_black
        return -MATE_VALUE
    elseif status in (
        :stalemate, :draw_insufficient_material, :draw_threefold, :draw_fiftymove)
        return 0
    end

    score = 0
    for (p, bb) in enumerate(board.bitboards)
        while bb != 0
            square = trailing_zeros(bb)  # index of least significant 1-bit (0..63)
            score += piece_square_value(p, square, board.game_phase_value)
            bb &= bb - 1  # clear that bit
        end
    end
    return score
end

"""
    compute_eval_and_phase(board::Board) -> (Int, Int)

Compute the evaluation score (from White's perspective) and the game phase value
from scratch for a given board.
"""
function compute_eval_and_phase(board::Board)
    eval_score = 0
    game_phase_value = 0

    for (piece, bb) in enumerate(board.bitboards)
        while bb != 0
            sq = trailing_zeros(bb)
            bb &= bb - 1

            game_phase_value += phase_weight(piece)
        end
    end

    # Now compute evaluation using that phase
    for (piece, bb) in enumerate(board.bitboards)
        tmp_bb = bb
        while tmp_bb != 0
            sq = trailing_zeros(tmp_bb)
            tmp_bb &= tmp_bb - 1
            eval_score += piece_square_value(piece, sq, game_phase_value)
        end
    end

    return eval_score, game_phase_value
end
