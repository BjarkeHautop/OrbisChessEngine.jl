# TODO: Add further checks for valid FEN strings such as castling rights

using StaticArrays

function board_from_fen(fen::String)
    parts = split(fen)
    @assert length(parts)>=4 "FEN must have at least 4 fields"

    # Piece placement
    rows = split(parts[1], '/')
    @assert length(rows)==8 "FEN must have 8 ranks"

    # Temporary mutable vector for bitboards
    bb_vec = zeros(UInt64, NUM_PIECES)

    # Map FEN chars to piece types
    PIECE_MAP = Dict(
        'P' => Piece.W_PAWN, 'N' => Piece.W_KNIGHT, 'B' => Piece.W_BISHOP,
        'R' => Piece.W_ROOK, 'Q' => Piece.W_QUEEN, 'K' => Piece.W_KING,
        'p' => Piece.B_PAWN, 'n' => Piece.B_KNIGHT, 'b' => Piece.B_BISHOP,
        'r' => Piece.B_ROOK, 'q' => Piece.B_QUEEN, 'k' => Piece.B_KING
    )

    for (rank_idx, row) in enumerate(rows)
        file = 0
        for c in row
            if isdigit(c)
                file += parse(Int, c)
            else
                sq = (8 - rank_idx) * 8 + file  # 0..63, A8=0
                piece = PIECE_MAP[c]
                bb_vec[piece] |= UInt64(1) << sq
                file += 1
            end
        end
        @assert file==8 "Each rank must have 8 squares"
    end

    bitboards = MVector{NUM_PIECES, UInt64}(bb_vec)

    # Side to move
    side_to_move = parts[2] == "w" ? WHITE : BLACK

    # Castling rights: KQkq as bits 0..3
    cr = UInt8(0)
    for c in parts[3]
        cr |= c == 'K' ? 0x1 : 0
        cr |= c == 'Q' ? 0x2 : 0
        cr |= c == 'k' ? 0x4 : 0
        cr |= c == 'q' ? 0x8 : 0
    end

    # En passant square
    ep = parts[4] == "-" ? -1 : Int8(square_index(parts[4]))

    # Halfmove clock
    halfmove = length(parts) >= 5 ? UInt16(parse(Int, parts[5])) : UInt16(0)

    # Preallocate position_history and undo_stack to fixed size
    pos_hist = MVector{MAX_MOVES_PER_GAME, UInt64}(zeros(UInt64, MAX_MOVES_PER_GAME))
    undo_stk = MVector{MAX_MOVES_PER_GAME, UndoInfo}(undef)

    # Initialize Board
    board = Board(
        bitboards,
        side_to_move,
        cr,
        ep,
        halfmove,
        pos_hist,
        undo_stk,
        Int16(0), # undo_stack pointer
        Int32(0), # eval_score placeholder
        UInt8(0) # game_phase_value placeholder
    )
    # Initial position hash
    board.position_history[1] = zobrist_hash(board)

    # Compute cached values
    board.eval_score, board.game_phase_value = compute_eval_and_phase(board)

    return board
end
