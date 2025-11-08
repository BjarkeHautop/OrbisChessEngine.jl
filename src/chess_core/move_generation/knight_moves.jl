# Preallocate a 64-element constant array
const knight_attack_masks = Vector{UInt64}(undef, 64)

function init_knight_masks!()
    for sq in 0:63
        mask = zero(UInt64)
        f, r = sq % 8, sq ÷ 8
        for df in (-2, -1, 1, 2)
            for dr in (-2, -1, 1, 2)
                if abs(df) != abs(dr)  # L-shape
                    tf, tr = f + df, r + dr
                    if 0 <= tf < 8 && 0 <= tr < 8
                        mask |= UInt64(1) << (tr * 8 + tf)
                    end
                end
            end
        end
        knight_attack_masks[sq + 1] = mask
    end
end

# Initialize once at startup
init_knight_masks!()

function generate_knight_moves!(board::Board, moves, start_idx::Int)
    idx = start_idx

    if board.side_to_move == WHITE
        knights = board.bitboards[Piece.W_KNIGHT]
        friendly_mask = board.bitboards[Piece.W_PAWN] | board.bitboards[Piece.W_KNIGHT] |
                        board.bitboards[Piece.W_BISHOP] | board.bitboards[Piece.W_ROOK] |
                        board.bitboards[Piece.W_QUEEN] | board.bitboards[Piece.W_KING]
        enemy_mask = board.bitboards[Piece.B_PAWN] | board.bitboards[Piece.B_KNIGHT] |
                     board.bitboards[Piece.B_BISHOP] | board.bitboards[Piece.B_ROOK] |
                     board.bitboards[Piece.B_QUEEN] | board.bitboards[Piece.B_KING]
        enemy_range = (Piece.B_PAWN):(Piece.B_KING)
    else
        knights = board.bitboards[Piece.B_KNIGHT]
        friendly_mask = board.bitboards[Piece.B_PAWN] | board.bitboards[Piece.B_KNIGHT] |
                        board.bitboards[Piece.B_BISHOP] | board.bitboards[Piece.B_ROOK] |
                        board.bitboards[Piece.B_QUEEN] | board.bitboards[Piece.B_KING]
        enemy_mask = board.bitboards[Piece.W_PAWN] | board.bitboards[Piece.W_KNIGHT] |
                     board.bitboards[Piece.W_BISHOP] | board.bitboards[Piece.W_ROOK] |
                     board.bitboards[Piece.W_QUEEN] | board.bitboards[Piece.W_KING]
        enemy_range = (Piece.W_PAWN):(Piece.W_KING)
    end

    bb = knights
    while bb != 0
        sq = trailing_zeros(bb)
        bb &= bb - 1

        attacks = knight_attack_masks[sq + 1] & ~friendly_mask
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

            moves[idx] = Move(sq, to_sq; capture = capture)
            idx += 1
        end
    end

    return idx  # new length of moves array after adding knight moves
end

function generate_knight_moves(board::Board)
    moves = Vector{Move}(undef, 64)  # Preallocate maximum possible moves
    start_idx = 1
    end_idx = generate_knight_moves!(board, moves, start_idx)
    return moves[1:(end_idx - 1)]  # Return only the filled portion
end
