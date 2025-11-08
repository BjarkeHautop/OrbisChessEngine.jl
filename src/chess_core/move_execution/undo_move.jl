"""
    undo_move!(board::Board, m::Move)

Undo move `m` on `board` in place, restoring previous state.
- `board`: Board struct
- `m`: Move struct
"""
function undo_move!(board::Board, m::Move)
    if board.undo_index == 0
        error("Undo stack empty!")
    end

    # --- 1. Flip side back ---
    board.side_to_move = board.side_to_move == WHITE ? BLACK : WHITE

    # --- 2. Restore position history and undo stack ---
    pos_index = board.undo_index + 1
    u = board.undo_stack[board.undo_index]
    board.undo_index -= 1  # pop

    moved_piece = u.moved_piece

    # --- 3. Restore moved piece ---
    if u.promotion != 0
        board.bitboards[u.promotion] = clearbit(board.bitboards[u.promotion], m.to)
        # Restore the original piece that moved (u.moved_piece)
        board.bitboards[u.moved_piece] = setbit(board.bitboards[u.moved_piece], m.from)
    else
        board.bitboards[u.moved_piece] = clearbit(board.bitboards[u.moved_piece], m.to)
        board.bitboards[u.moved_piece] = setbit(board.bitboards[u.moved_piece], m.from)
    end

    # --- 4. Restore captured piece ---
    if u.is_en_passant
        captured_square = board.side_to_move == WHITE ? m.to - 8 : m.to + 8
        board.bitboards[u.captured_piece] = setbit(
            board.bitboards[u.captured_piece], captured_square)
    elseif u.captured_piece != 0
        board.bitboards[u.captured_piece] = setbit(board.bitboards[u.captured_piece], m.to)
    end

    # --- 5. Undo castling rook move if necessary ---
    if abs(m.to - m.from) == 2 &&
       (moved_piece == Piece.W_KING || moved_piece == Piece.B_KING)
        if m.to == 6 # White short castle
            board.bitboards[Piece.W_ROOK] = clearbit(board.bitboards[Piece.W_ROOK], 5)
            board.bitboards[Piece.W_ROOK] = setbit(board.bitboards[Piece.W_ROOK], 7)
        elseif m.to == 2 # White long castle
            board.bitboards[Piece.W_ROOK] = clearbit(board.bitboards[Piece.W_ROOK], 3)
            board.bitboards[Piece.W_ROOK] = setbit(board.bitboards[Piece.W_ROOK], 0)
        elseif m.to == 62 # Black short castle
            board.bitboards[Piece.B_ROOK] = clearbit(board.bitboards[Piece.B_ROOK], 61)
            board.bitboards[Piece.B_ROOK] = setbit(board.bitboards[Piece.B_ROOK], 63)
        elseif m.to == 58 # Black long castle
            board.bitboards[Piece.B_ROOK] = clearbit(board.bitboards[Piece.B_ROOK], 59)
            board.bitboards[Piece.B_ROOK] = setbit(board.bitboards[Piece.B_ROOK], 56)
        end
    end

    # --- 6. Restore auxiliary board state ---
    board.en_passant = u.en_passant
    board.castling_rights = u.castling_rights
    board.halfmove_clock = u.halfmove_clock
    board.eval_score = u.prev_eval_score
    board.game_phase_value = u.prev_game_phase_value

    # --- 7. Restore position history ---
    board.position_history[pos_index] = 0

    return nothing
end

"""
    undo_move(board::Board, m::Move) -> Board

Return a new board with move `m` undone, leaving the original board unchanged.
- `board`: Board struct
- `m`: Move struct
"""
function undo_move(board::Board, m::Move)
    board_copy = deepcopy(board)
    undo_move!(board_copy, m)
    return board_copy
end
