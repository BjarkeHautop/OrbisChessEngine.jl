# Update to don't use pop! and push! on undo_stack and position_history

"""
Apply a null move (pass) to the board, modifying it in place.
Used for null-move pruning.
"""
function make_null_move!(board::Board)
    board.undo_index += 1
    pos_index = board.undo_index + 1

    # Save UndoInfo
    board.undo_stack[board.undo_index] = UndoInfo(
        0,                    # captured piece (none)
        board.en_passant,
        board.castling_rights,
        board.halfmove_clock,
        0,                    # moved_piece (none)
        0,                    # promotion (none)
        false,                # not en passant
        board.eval_score,
        board.game_phase_value,
    )

    # --- Initialize incremental Zobrist hash ---
    h = board.position_history[board.undo_index]  # current hash

    # --- Remove old en passant ---
    if board.en_passant != -1
        h ⊻= ZOBRIST_EP[(board.en_passant%8)+1]
    end

    # --- Clear en passant ---
    board.en_passant = -1

    # --- Halfmove clock increment ---
    board.halfmove_clock += 1

    # --- Flip side to move ---
    board.side_to_move = board.side_to_move == WHITE ? BLACK : WHITE
    h ⊻= ZOBRIST_SIDE[]

    # --- Save updated hash ---
    board.position_history[pos_index] = h

    return nothing
end

"""
Undo a null move, restoring the previous board state.
"""
function undo_null_move!(board::Board)
    if board.undo_index == 0
        error("Undo stack underflow in undo_null_move!")
    end
    pos_index = board.undo_index + 1
    u = board.undo_stack[board.undo_index]
    board.undo_index -= 1  # pop

    board.en_passant = u.en_passant
    board.castling_rights = u.castling_rights
    board.halfmove_clock = u.halfmove_clock
    board.eval_score = u.prev_eval_score
    board.game_phase_value = u.prev_game_phase_value

    # Flip side back
    board.side_to_move = board.side_to_move == WHITE ? BLACK : WHITE

    # Clear the corresponding hash slot
    board.position_history[pos_index] = 0

    return nothing
end
