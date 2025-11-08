# Precompute king moves for all 64 squares
const king_attack_masks = Vector{UInt64}(undef, 64)

function init_king_masks!()
    for sq in 0:63
        mask = zero(UInt64)
        f, r = sq % 8, sq ÷ 8
        for df in -1:1
            for dr in -1:1
                if df == 0 && dr == 0
                    continue
                end
                nf, nr = f + df, r + dr
                if 0 ≤ nf < 8 && 0 ≤ nr < 8
                    mask |= UInt64(1) << (nr * 8 + nf)
                end
            end
        end
        king_attack_masks[sq + 1] = mask
    end
end

# Initialize once
init_king_masks!()

function generate_king_moves!(board::Board, moves, start_idx::Int = 1)
    idx = start_idx

    # Choose correct side bitboards
    if board.side_to_move == WHITE
        kings = board.bitboards[Piece.W_KING]
        friendly_mask = board.bitboards[Piece.W_PAWN] | board.bitboards[Piece.W_KNIGHT] |
                        board.bitboards[Piece.W_BISHOP] | board.bitboards[Piece.W_ROOK] |
                        board.bitboards[Piece.W_QUEEN] | board.bitboards[Piece.W_KING]
        enemy_mask = board.bitboards[Piece.B_PAWN] | board.bitboards[Piece.B_KNIGHT] |
                     board.bitboards[Piece.B_BISHOP] | board.bitboards[Piece.B_ROOK] |
                     board.bitboards[Piece.B_QUEEN] | board.bitboards[Piece.B_KING]
        enemy_range = (Piece.B_PAWN):(Piece.B_KING)
        rights = board.castling_rights
        king_sq = trailing_zeros(kings)
    else
        kings = board.bitboards[Piece.B_KING]
        friendly_mask = board.bitboards[Piece.B_PAWN] | board.bitboards[Piece.B_KNIGHT] |
                        board.bitboards[Piece.B_BISHOP] | board.bitboards[Piece.B_ROOK] |
                        board.bitboards[Piece.B_QUEEN] | board.bitboards[Piece.B_KING]
        enemy_mask = board.bitboards[Piece.W_PAWN] | board.bitboards[Piece.W_KNIGHT] |
                     board.bitboards[Piece.W_BISHOP] | board.bitboards[Piece.W_ROOK] |
                     board.bitboards[Piece.W_QUEEN] | board.bitboards[Piece.W_KING]
        enemy_range = (Piece.W_PAWN):(Piece.W_KING)
        rights = board.castling_rights
        king_sq = trailing_zeros(kings)
    end

    # Regular king moves
    attacks = king_attack_masks[king_sq + 1] & ~friendly_mask
    attack_bb = attacks
    while attack_bb != 0
        to_sq = trailing_zeros(attack_bb)
        attack_bb &= attack_bb - 1

        capture = 0
        if enemy_mask & (UInt64(1) << to_sq) != 0
            for p in enemy_range
                if board.bitboards[p] & (UInt64(1) << to_sq) != 0
                    capture = p
                    break
                end
            end
        end

        moves[idx] = Move(king_sq, to_sq; capture = capture)
        idx += 1
    end

    # =============== Castling (pseudo-legal) ===============
    occupied_mask = friendly_mask | enemy_mask
    if board.side_to_move == WHITE
        if (rights & 0b0001) != 0 &&
           ((occupied_mask & ((UInt64(1) << 5) | (UInt64(1) << 6))) == 0)
            moves[idx] = Move(4, 6; castling = 1)
            idx += 1
        end
        if (rights & 0b0010) != 0 &&
           ((occupied_mask & ((UInt64(1) << 1) | (UInt64(1) << 2) | (UInt64(1) << 3))) == 0)
            moves[idx] = Move(4, 2; castling = 2)
            idx += 1
        end
    else
        if (rights & 0b0100) != 0 &&
           ((occupied_mask & ((UInt64(1) << 61) | (UInt64(1) << 62))) == 0)
            moves[idx] = Move(60, 62; castling = 1)
            idx += 1
        end
        if (rights & 0b1000) != 0 &&
           ((occupied_mask & ((UInt64(1) << 57) | (UInt64(1) << 58) | (UInt64(1) << 59))) ==
            0)
            moves[idx] = Move(60, 58; castling = 2)
            idx += 1
        end
    end
    return idx # new length of moves array after adding king moves
end

function generate_king_moves(board::Board)
    moves = Vector{Move}(undef, 64)  # Preallocate maximum possible moves
    start_idx = 1
    end_idx = generate_king_moves!(board, moves, start_idx)
    return moves[1:(end_idx - 1)]  # Return only the filled portion
end
