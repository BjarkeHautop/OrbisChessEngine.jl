const pawn_attack_masks_white = Vector{UInt64}(undef, 64)
const pawn_attack_masks_black = Vector{UInt64}(undef, 64)

function init_pawn_masks!()
    for sq in 0:63
        mask_white = zero(UInt64)
        mask_black = zero(UInt64)
        f, r = sq % 8, sq ÷ 8

        # White pawns attack "up-left" and "up-right"
        for df in (-1, 1)
            tf, tr = f + df, r - 1   # moving up for white
            if 0 <= tf < 8 && 0 <= tr < 8
                mask_white |= UInt64(1) << (tr * 8 + tf)
            end
        end

        # Black pawns attack "down-left" and "down-right"
        for df in (-1, 1)
            tf, tr = f + df, r + 1   # moving down for black
            if 0 <= tf < 8 && 0 <= tr < 8
                mask_black |= UInt64(1) << (tr * 8 + tf)
            end
        end

        pawn_attack_masks_white[sq + 1] = mask_white
        pawn_attack_masks_black[sq + 1] = mask_black
    end
end

init_pawn_masks!()

"""
Generate pseudo-legal pawn moves in-place
- `board`: Board struct
- `moves`: preallocated buffer to append moves
Returns: number of moves added
"""
function generate_pawn_moves!(board::Board, moves, start_idx::Int)
    idx = start_idx

    # Setup depending on side
    if board.side_to_move == WHITE
        pawns = board.bitboards[Piece.W_PAWN]
        enemy_mask = board.bitboards[Piece.B_PAWN] | board.bitboards[Piece.B_KNIGHT] |
                     board.bitboards[Piece.B_BISHOP] | board.bitboards[Piece.B_ROOK] |
                     board.bitboards[Piece.B_QUEEN] | board.bitboards[Piece.B_KING]
        promo_rank_mask = UInt64(0xFF00000000000000)
        start_rank_mask = UInt64(0x000000000000FF00)
        direction = 8
        left_capture_offset = 7
        right_capture_offset = 9
        promo_pieces = (Piece.W_QUEEN, Piece.W_ROOK, Piece.W_BISHOP, Piece.W_KNIGHT)
        ep_capture_piece = Piece.B_PAWN
    else
        pawns = board.bitboards[Piece.B_PAWN]
        enemy_mask = board.bitboards[Piece.W_PAWN] | board.bitboards[Piece.W_KNIGHT] |
                     board.bitboards[Piece.W_BISHOP] | board.bitboards[Piece.W_ROOK] |
                     board.bitboards[Piece.W_QUEEN] | board.bitboards[Piece.W_KING]
        promo_rank_mask = UInt64(0x00000000000000FF)
        start_rank_mask = UInt64(0x00FF000000000000)
        direction = -8
        left_capture_offset = -9
        right_capture_offset = -7
        promo_pieces = (Piece.B_QUEEN, Piece.B_ROOK, Piece.B_BISHOP, Piece.B_KNIGHT)
        ep_capture_piece = Piece.W_PAWN
    end

    all_occupied = pawns |
                   (board.bitboards[Piece.W_PAWN] | board.bitboards[Piece.W_KNIGHT] |
                    board.bitboards[Piece.W_BISHOP] | board.bitboards[Piece.W_ROOK] |
                    board.bitboards[Piece.W_QUEEN] | board.bitboards[Piece.W_KING] |
                    board.bitboards[Piece.B_PAWN] | board.bitboards[Piece.B_KNIGHT] |
                    board.bitboards[Piece.B_BISHOP] | board.bitboards[Piece.B_ROOK] |
                    board.bitboards[Piece.B_QUEEN] | board.bitboards[Piece.B_KING])

    pawn_bb = pawns
    while pawn_bb != 0
        sq = trailing_zeros(pawn_bb)
        pawn_bb &= pawn_bb - 1

        # single push
        to_sq = sq + direction
        if 0 <= to_sq < 64 && ((all_occupied & (UInt64(1) << to_sq)) == 0)
            if (UInt64(1) << to_sq) & promo_rank_mask != 0
                for promo in promo_pieces
                    moves[idx] = Move(sq, to_sq; promotion = promo)
                    idx += 1
                end
            else
                moves[idx] = Move(sq, to_sq)
                idx += 1
            end

            # double push
            if (UInt64(1) << sq) & start_rank_mask != 0
                to_sq2 = sq + 2 * direction
                if 0 <= to_sq2 < 64 && (all_occupied & (UInt64(1) << to_sq2)) == 0
                    moves[idx] = Move(sq, to_sq2)
                    idx += 1
                end
            end
        end

        # captures
        for offset in (left_capture_offset, right_capture_offset)
            # check file boundaries
            file_ok = (offset in (left_capture_offset,) && sq % 8 != 0) ||
                      (offset in (right_capture_offset,) && sq % 8 != 7)
            if file_ok
                to_sq = sq + offset
                if 0 <= to_sq < 64 && (enemy_mask & (UInt64(1) << to_sq)) != 0
                    capture_piece = find_capture_piece(
                        board, to_sq,
                        board.side_to_move == WHITE ? Piece.B_PAWN : Piece.W_PAWN,
                        board.side_to_move == WHITE ? Piece.B_KING : Piece.W_KING
                    )
                    if (UInt64(1) << to_sq) & promo_rank_mask != 0
                        for promo in promo_pieces
                            moves[idx] = Move(sq, to_sq;
                                capture = capture_piece, promotion = promo)
                            idx += 1
                        end
                    else
                        moves[idx] = Move(sq, to_sq; capture = capture_piece)
                        idx += 1
                    end
                end
            end
        end

        # en passant
        if board.en_passant != -1
            ep_sq = board.en_passant
            if (sq % 8 != 0 && sq + left_capture_offset == ep_sq) ||
               (sq % 8 != 7 && sq + right_capture_offset == ep_sq)
                moves[idx] = Move(sq, ep_sq; capture = ep_capture_piece, en_passant = true)
                idx += 1
            end
        end
    end
    return idx # new length of moves after adding pawn moves
end

"""
Generate pseudo-legal pawn moves for the side to move
- `board`: Board struct
Returns: Vector of Move
"""
function generate_pawn_moves(board::Board)
    moves = Vector{Move}(undef, 64)  # Preallocate maximum possible moves
    start_idx = 1
    end_idx = generate_pawn_moves!(board, moves, start_idx)
    return moves[1:(end_idx - 1)]  # Return only the filled portion
end
