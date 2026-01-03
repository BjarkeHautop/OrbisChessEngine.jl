"""
    make_move!(board::Board, m::Move)

Apply the move `m` to `board` **in-place**, updating the board state, castling rights, en passant square,
halfmove clock, and internal evaluation.

- `board`: a `Board` struct representing the current chess position.
- `m`: a `Move` object. Typically created from a long algebraic notation (LAN) string using `Move(board, "e2e4")`.

# Example

```julia
board = Board()
mv = Move(board, "e2e4")
make_move!(board, mv)
```
"""
function make_move!(board::Board, m::Move)
    # --- Identify moving piece ---
    piece_type = 0
    if board.side_to_move == WHITE
        for p in (Piece.W_PAWN):(Piece.W_KING)
            if testbit(board.bitboards[p], m.from)
                piece_type = p
                break
            end
        end
    else
        for p in (Piece.B_PAWN):(Piece.B_KING)
            if testbit(board.bitboards[p], m.from)
                piece_type = p
                break
            end
        end
    end
    piece_type == 0 && error("No piece found on from-square $(m.from)")

    # --- Detect en passant capture ---
    is_ep = piece_type in (Piece.W_PAWN, Piece.B_PAWN) && m.to == board.en_passant

    # --- Save UndoInfo at current undo_index ---
    board.undo_index += 1
    if board.undo_index > length(board.undo_stack)
        error("Undo stack full!")
    end
    board.undo_stack[board.undo_index] = UndoInfo(
        m.capture,
        board.en_passant,
        board.castling_rights,
        board.halfmove_clock,
        piece_type,
        m.promotion,
        is_ep,
        board.eval_score,
        board.game_phase_value
    )

    # --- Initialize incremental Zobrist hash ---
    h = board.position_history[board.undo_index]  # current hash before move

    # --- Remove moving piece from origin ---
    board.bitboards[piece_type] = clearbit(board.bitboards[piece_type], m.from)
    h ⊻= ZOBRIST_PIECES[piece_type, m.from + 1]  # remove piece from origin

    board.eval_score -= piece_square_value(piece_type, m.from, board.game_phase_value)

    # --- Captures ---
    if m.capture != 0 && !is_ep
        board.bitboards[m.capture] = clearbit(board.bitboards[m.capture], m.to)
        h ⊻= ZOBRIST_PIECES[m.capture, m.to + 1]  # remove captured piece

        board.eval_score -= piece_square_value(m.capture, m.to, board.game_phase_value)
        board.game_phase_value -= phase_weight(m.capture)

    elseif is_ep
        if board.side_to_move == WHITE
            captured_sq = m.to - 8
            board.bitboards[Piece.B_PAWN] = clearbit(
                board.bitboards[Piece.B_PAWN], captured_sq)
            h ⊻= ZOBRIST_PIECES[Piece.B_PAWN, captured_sq + 1]

            board.eval_score -= piece_square_value(
                Piece.B_PAWN, captured_sq, board.game_phase_value)
            board.game_phase_value -= phase_weight(Piece.B_PAWN)
        else
            captured_sq = m.to + 8
            board.bitboards[Piece.W_PAWN] = clearbit(
                board.bitboards[Piece.W_PAWN], captured_sq)
            h ⊻= ZOBRIST_PIECES[Piece.W_PAWN, captured_sq + 1]

            board.eval_score -= piece_square_value(
                Piece.W_PAWN, captured_sq, board.game_phase_value)
            board.game_phase_value -= phase_weight(Piece.W_PAWN)
        end
    end

    # --- Promotions / normal move ---
    if m.promotion != 0
        board.bitboards[m.promotion] = setbit(board.bitboards[m.promotion], m.to)
        h ⊻= ZOBRIST_PIECES[m.promotion, m.to + 1]

        board.eval_score += piece_square_value(m.promotion, m.to, board.game_phase_value)
        board.game_phase_value += phase_weight(m.promotion)
        board.game_phase_value -= phase_weight(piece_type)
    else
        board.bitboards[piece_type] = setbit(board.bitboards[piece_type], m.to)
        h ⊻= ZOBRIST_PIECES[piece_type, m.to + 1]

        board.eval_score += piece_square_value(piece_type, m.to, board.game_phase_value)
    end

    # --- Castling rook moves ---
    if piece_type == Piece.W_KING && m.from == 4 && abs(m.to - m.from) == 2
        if m.to == 6
            # e1 → g1, rook h1→f1
            board.bitboards[Piece.W_ROOK] = clearbit(board.bitboards[Piece.W_ROOK], 7)
            board.bitboards[Piece.W_ROOK] = setbit(board.bitboards[Piece.W_ROOK], 5)
            h ⊻= ZOBRIST_PIECES[Piece.W_ROOK, 7 + 1]
            h ⊻= ZOBRIST_PIECES[Piece.W_ROOK, 5 + 1]

            board.eval_score -= piece_square_value(Piece.W_ROOK, 7, board.game_phase_value)
            board.eval_score += piece_square_value(Piece.W_ROOK, 5, board.game_phase_value)
        elseif m.to == 2
            # e1 → c1, rook a1→d1
            board.bitboards[Piece.W_ROOK] = clearbit(board.bitboards[Piece.W_ROOK], 0)
            board.bitboards[Piece.W_ROOK] = setbit(board.bitboards[Piece.W_ROOK], 3)
            h ⊻= ZOBRIST_PIECES[Piece.W_ROOK, 0 + 1]
            h ⊻= ZOBRIST_PIECES[Piece.W_ROOK, 3 + 1]

            board.eval_score -= piece_square_value(Piece.W_ROOK, 0, board.game_phase_value)
            board.eval_score += piece_square_value(Piece.W_ROOK, 3, board.game_phase_value)
        end
    elseif piece_type == Piece.B_KING && m.from == 60 && abs(m.to - m.from) == 2
        if m.to == 62
            # e8 → g8, rook h8→f8
            board.bitboards[Piece.B_ROOK] = clearbit(board.bitboards[Piece.B_ROOK], 63)
            board.bitboards[Piece.B_ROOK] = setbit(board.bitboards[Piece.B_ROOK], 61)
            h ⊻= ZOBRIST_PIECES[Piece.B_ROOK, 63 + 1]
            h ⊻= ZOBRIST_PIECES[Piece.B_ROOK, 61 + 1]

            board.eval_score -= piece_square_value(Piece.B_ROOK, 63, board.game_phase_value)
            board.eval_score += piece_square_value(Piece.B_ROOK, 61, board.game_phase_value)
        elseif m.to == 58
            # e8 → c8, rook a8→d8
            board.bitboards[Piece.B_ROOK] = clearbit(board.bitboards[Piece.B_ROOK], 56)
            board.bitboards[Piece.B_ROOK] = setbit(board.bitboards[Piece.B_ROOK], 59)
            h ⊻= ZOBRIST_PIECES[Piece.B_ROOK, 56 + 1]
            h ⊻= ZOBRIST_PIECES[Piece.B_ROOK, 59 + 1]

            board.eval_score -= piece_square_value(Piece.B_ROOK, 56, board.game_phase_value)
            board.eval_score += piece_square_value(Piece.B_ROOK, 59, board.game_phase_value)
        end
    end

    # --- En passant target square ---
    old_ep = board.en_passant
    if old_ep != -1
        h ⊻= ZOBRIST_EP[(old_ep % 8) + 1]
    end

    board.en_passant = -1
    if piece_type == Piece.W_PAWN && (m.to - m.from) == 16
        board.en_passant = m.from + 8
    elseif piece_type == Piece.B_PAWN && (m.from - m.to) == 16
        board.en_passant = m.from - 8
    end

    if board.en_passant != -1
        h ⊻= ZOBRIST_EP[(board.en_passant % 8) + 1]
    end

    # --- Castling rights ---
    old_castling = board.castling_rights
    new_castling = old_castling

    if piece_type == Piece.W_KING
        new_castling &= 0x0c
    elseif piece_type == Piece.B_KING
        new_castling &= 0x03
    end

    if piece_type == Piece.W_ROOK
        if m.from == 0
            new_castling &= 0x0d
        elseif m.from == 7
            new_castling &= 0x0e
        end
    elseif piece_type == Piece.B_ROOK
        if m.from == 56
            new_castling &= 0x07
        elseif m.from == 63
            new_castling &= 0x0b
        end
    end

    if m.capture == Piece.W_ROOK
        if m.to == 0
            new_castling &= 0x0d
        elseif m.to == 7
            new_castling &= 0x0e
        end
    elseif m.capture == Piece.B_ROOK
        if m.to == 56
            new_castling &= 0x07
        elseif m.to == 63
            new_castling &= 0x0b
        end
    end

    if new_castling != old_castling
        h ⊻= ZOBRIST_CASTLING[Int(old_castling) + 1]
        h ⊻= ZOBRIST_CASTLING[Int(new_castling) + 1]
    end
    board.castling_rights = new_castling

    # --- Halfmove clock ---
    if piece_type in (Piece.W_PAWN, Piece.B_PAWN) || m.capture != 0 || m.promotion != 0
        board.halfmove_clock = 0
    else
        board.halfmove_clock += 1
    end

    # --- Side to move ---
    board.side_to_move = (board.side_to_move == WHITE ? BLACK : WHITE)
    h ⊻= ZOBRIST_SIDE[]  # flip side

    # --- Save updated hash ---
    board.position_history[board.undo_index + 1] = h

    return nothing
end

"""
    make_move(board::Board, m::Move)

Return a **new board** with the move `m` applied, leaving the original `board` unchanged.
Updates castling rights, en passant square, halfmove clock, and internal evaluation.

- `board`: a `Board` struct representing the current chess position.
- `m`: a `Move` object. Typically created from a long algebraic notation (LAN) string using `Move(board, "e2e4")`.

# Example

```julia
board = Board()
mv = Move(board, "e2e4")
new_board = make_move(board, mv)
```
"""
function make_move(board::Board, m::Move)
    new_board = deepcopy(board)
    make_move!(new_board, m)
    return new_board
end

"""
    apply_moves!(board::Board, moves::AbstractString...)

Apply a sequence of moves in **long algebraic notation (LAN)** to `board` **in-place**.
Only legal moves are allowed; an error is thrown if any move is illegal.

Since this function modifies `board` in-place, all moves **up to the first illegal move** are applied.
The board will reflect these moves even if a subsequent move is illegal.

- `board`: a `Board` struct representing the current chess position.
- `moves`: one or more moves as LAN strings (e.g., `"e2e4"`, `"g1f3"`).

# Example

```julia
board = Board()
apply_moves!(board, "e2e4", "e7e5", "g1f3", "b8c6", "f1b5")
```
"""
function apply_moves!(board::Board, moves::AbstractString...)
    for (i, mstr) in enumerate(moves)
        legal = generate_legal_moves(board)
        idx = findfirst(m -> string(m) == mstr, legal)
        idx === nothing && error("Illegal move '$mstr' at move $i")
        mv = legal[idx]
        make_move!(board, mv)
    end
    return board
end

"""
    apply_moves(board::Board, moves::AbstractString...) -> Board

Return a **new board** with a sequence of moves in **long algebraic notation (LAN)** applied.
The original `board` is left unchanged. Only legal moves are allowed; an error is thrown if any move is illegal.

- `board`: a `Board` struct representing the current chess position.
- `moves`: one or more moves as LAN strings (e.g., `"e2e4"`, `"g1f3"`).

# Example

```julia
board = Board()  # starting position
new_board = apply_moves(board, "e2e4", "e7e5", "g1f3", "b8c6", "f1b5")
```
"""
function apply_moves(board::Board, moves::AbstractString...)
    new_board = deepcopy(board)
    apply_moves!(new_board, moves...)
    return new_board
end
