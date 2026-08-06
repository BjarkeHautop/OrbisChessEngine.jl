#########################
# Move helpers          #
#########################

on_board(sq) = 0 <= sq <= 63

"""
    file_rank(sq) -> (Int, Int)

Return file (1..8) and rank (1..8) for a square index
"""
file_rank(sq) = (sq % 8 + 1, sq ÷ 8 + 1)

"""
    king_square(board::Board, side::Side) -> Int

Get the square index of the king for the given side
- `board`: Board struct
- `side`: Side (WHITE or BLACK)
Returns: Int (square index 0..63)
"""
function king_square(board::Board, side::Side)
    bb = (side == WHITE) ? board.bitboards[Piece.W_KING] : board.bitboards[Piece.B_KING]
    return trailing_zeros(bb)
end

"""
    piece_at(board::Board, sq) -> Int

Return the piece type at a given square (0..63) using bitboards.
"""
function piece_at(board::Board, sq)
    mask = UInt64(1) << sq
    for (p, bb) in enumerate(board.bitboards)
        if bb & mask != 0
            return p
        end
    end
    return 0
end

function attacked_by_sliders(occ, sq, directions, bb_piece)
    for d in directions
        pos = sq
        prev_f, prev_r = file_rank(pos)
        while true
            pos += d
            if !on_board(pos)
                break
            end
            f, r = file_rank(pos)
            if abs(f - prev_f) > 1 || abs(r - prev_r) > 1
                break
            end
            prev_f, prev_r = f, r

            if testbit(occ, pos)
                if testbit(bb_piece, pos)
                    return true   # correct slider found
                else
                    break        # blocked by wrong piece
                end
            end
        end
    end
    return false
end

"""
    square_attacked(board, sq, attacker) -> Bool

Check if a square is attacked by the given side.
- `board`: Board struct
- `sq`: Int (square index 0..63)
- `attacker`: Side (WHITE or BLACK)
Returns: Bool
"""
function square_attacked(board::Board, sq, attacker::Side)::Bool
    # 1) Pawn attacks
    pawns =
        attacker == WHITE ? board.bitboards[Piece.W_PAWN] : board.bitboards[Piece.B_PAWN]
    mask = attacker == WHITE ? pawn_attack_masks_white[sq+1] : pawn_attack_masks_black[sq+1]
    if (pawns & mask) != 0
        return true
    end

    # --- 2) Knight attacks ---
    knights =
        attacker == WHITE ? board.bitboards[Piece.W_KNIGHT] :
        board.bitboards[Piece.B_KNIGHT]
    if (knights & knight_attack_masks[sq+1]) != 0
        return true
    end

    # --- 3) King attacks ---
    kings =
        attacker == WHITE ? board.bitboards[Piece.W_KING] : board.bitboards[Piece.B_KING]
    if (kings & king_attack_masks[sq+1]) != 0
        return true
    end

    # 3) Sliding pieces
    occ = zero(UInt64)
    for p in ALL_PIECES
        occ |= board.bitboards[p]
    end

    # Bishops + queens (diagonals)
    if attacked_by_sliders(
        occ,
        sq,
        DIAGONAL_DIRS,
        if (attacker == WHITE)
            (board.bitboards[Piece.W_BISHOP] | board.bitboards[Piece.W_QUEEN])
        else
            (board.bitboards[Piece.B_BISHOP] | board.bitboards[Piece.B_QUEEN])
        end,
    )
        return true
    end

    # Rooks + queens (orthogonals)
    if attacked_by_sliders(
        occ,
        sq,
        ORTHOGONAL_DIRS,
        if (attacker == WHITE)
            (board.bitboards[Piece.W_ROOK] | board.bitboards[Piece.W_QUEEN])
        else
            (board.bitboards[Piece.B_ROOK] | board.bitboards[Piece.B_QUEEN])
        end,
    )
        return true
    end

    return false
end

"""
    in_check(board::Board, side::Side) -> Bool

Check if the king of the given side is in check
- `board`: Board struct
- `side`: Side (WHITE or BLACK)
Returns: Bool
"""
function in_check(board::Board, side::Side)::Bool
    king_sq = king_square(board, side)
    attacker = opposite(side)
    return square_attacked(board, king_sq, attacker)
end

function generate_captures!(board::Board, moves, pseudo)
    n_moves = generate_legal_moves!(board, moves, pseudo)

    write_idx = 1
    @inbounds for i = 1:n_moves
        m = moves[i]
        if m.capture != 0
            moves[write_idx] = m
            write_idx += 1
        end
    end

    return write_idx - 1
end

# helper to find which enemy piece occupies a square
function find_capture_piece(board::Board, sq, start_piece, end_piece)
    for p = start_piece:end_piece
        if (board.bitboards[p] & (UInt64(1) << sq)) != 0
            return p
        end
    end
    return 0
end
