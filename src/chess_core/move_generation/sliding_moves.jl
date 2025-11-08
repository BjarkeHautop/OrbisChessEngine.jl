# Internal helper for sliding moves
const WHITE_PIECES = (Piece.W_PAWN):(Piece.W_KING)
const BLACK_PIECES = (Piece.B_PAWN):(Piece.B_KING)
const DIAGONAL_DIRS = [-9, -7, 7, 9]
const ORTHOGONAL_DIRS = [-8, -1, 1, 8]
const ALL_DIRS = [-9, -8, -7, -1, 1, 7, 8, 9]

function generate_sliding_moves!(
        board::Board,
        bb_piece::UInt64,
        directions::Vector{Int},
        moves,
        start_idx::Int
)
    idx = start_idx

    if board.side_to_move == WHITE
        friendly_pieces = WHITE_PIECES
        enemy_pieces = BLACK_PIECES
    else
        friendly_pieces = BLACK_PIECES
        enemy_pieces = WHITE_PIECES
    end

    # Bitboard of all friendly pieces
    occupied_friendly = zero(UInt64)
    for p in friendly_pieces
        occupied_friendly |= board.bitboards[p]
    end

    @inbounds for sq in 0:63
        if !testbit(bb_piece, sq)
            continue
        end
        f, r = file_rank(sq)

        for d in directions
            to_sq = sq
            prev_f, prev_r = f, r

            while true
                to_sq += d
                if !on_board(to_sq)
                    break
                end

                tf, tr = file_rank(to_sq)
                if abs(tf - prev_f) > 1 || abs(tr - prev_r) > 1
                    break
                end
                prev_f, prev_r = tf, tr

                # Stop if blocked by friendly piece
                if testbit(occupied_friendly, to_sq)
                    break
                end

                # Check for capture
                capture = 0
                for p in enemy_pieces
                    if testbit(board.bitboards[p], to_sq)
                        capture = p
                        break
                    end
                end

                moves[idx] = Move(sq, to_sq; capture = capture)
                idx += 1

                # Stop sliding if captured
                if capture != 0
                    break
                end
            end
        end
    end

    return idx  # new length after adding all sliding moves
end

# In-place bishop moves
function generate_bishop_moves!(board::Board, moves, start_idx::Int)
    bb = board.side_to_move == WHITE ? board.bitboards[Piece.W_BISHOP] :
         board.bitboards[Piece.B_BISHOP]
    return generate_sliding_moves!(board, bb, DIAGONAL_DIRS, moves, start_idx)
end

# In-place rook moves
function generate_rook_moves!(board::Board, moves, start_idx::Int)
    bb = board.side_to_move == WHITE ? board.bitboards[Piece.W_ROOK] :
         board.bitboards[Piece.B_ROOK]
    return generate_sliding_moves!(board, bb, ORTHOGONAL_DIRS, moves, start_idx)
end

# In-place queen moves
function generate_queen_moves!(board::Board, moves, start_idx::Int)
    bb = board.side_to_move == WHITE ? board.bitboards[Piece.W_QUEEN] :
         board.bitboards[Piece.B_QUEEN]
    return generate_sliding_moves!(board, bb, ALL_DIRS, moves, start_idx)
end

function generate_bishop_moves(board::Board)
    moves = Vector{Move}(undef, 256)  # preallocate a large enough buffer
    start_idx = 1
    end_idx = generate_bishop_moves!(board, moves, start_idx)
    return moves[1:(end_idx - 1)]
end

function generate_rook_moves(board::Board)
    moves = Vector{Move}(undef, 256)  # preallocate a large enough buffer
    start_idx = 1
    end_idx = generate_rook_moves!(board, moves, start_idx)
    return moves[1:(end_idx - 1)]
end

function generate_queen_moves(board::Board)
    moves = Vector{Move}(undef, 256)  # preallocate a large enough buffer
    start_idx = 1
    end_idx = generate_queen_moves!(board, moves, start_idx)
    return moves[1:(end_idx - 1)]
end
