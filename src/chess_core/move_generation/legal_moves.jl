const ROOK_DIRECTIONS = [(1, 0), (-1, 0), (0, 1), (0, -1)]
const SLIDING_DIRECTIONS = vcat(ROOK_DIRECTIONS, BISHOP_DIRECTIONS)
"""
    ray_between(board, king_sq::Int, from_sq::Int) -> Bool

Returns true if moving a piece from `from_sq` could open a sliding attack (rook, bishop, queen)
towards the king at `king_sq`.
"""
function ray_between(occ, king_sq, from_sq)
    @inbounds for dir in SLIDING_DIRECTIONS
        sq = king_sq
        while true
            sq = next_square(sq, dir)
            sq === nothing && break
            if sq == from_sq
                return true
            elseif ((occ >> sq) & 0x1) != 0
                break
            end
        end
    end
    return false
end

"""
    next_square(sq::Int, dir::Tuple{Int,Int}) -> Union{Int,Nothing}

Returns the next square index in direction `dir = (df, dr)` from `sq`.
Returns `nothing` if it goes off-board.
"""
function next_square(sq::Int, dir::Tuple{Int, Int})
    f, r = file_rank(sq)  # current file/rank (1..8)
    nf, nr = f + dir[1], r + dir[2]

    # check bounds
    if 1 <= nf <= 8 && 1 <= nr <= 8
        return square_index(nf, nr)
    else
        return nothing
    end
end

"""
    occupancy(board::Board) -> UInt64

Returns a bitboard of all occupied squares.
"""
@inline function occupancy(board::Board)
    occ = UInt64(0)
    for bb in board.bitboards
        occ |= bb
    end
    return occ
end

function is_move_legal(board::Board, m::Move, side::Side,
        king_sq::Int, occ, in_check_now::Bool)::Bool
    # --- Castling check ---
    if m.castling != 0
        path = if side == WHITE
            m.castling == 1 ? (5, 6) : (3, 2)
        else
            m.castling == 1 ? (61, 62) : (59, 58)
        end
        if in_check_now || any(sq -> square_attacked(board, sq, opposite(side)), path)
            return false
        end
    end

    if !in_check_now && !ray_between(occ, king_sq, m.from) && m.from != king_sq
        return true
    else
        make_move!(board, m)
        legal = !in_check(board, side)
        undo_move!(board, m)
        return legal
    end
end

"""
    _filter_legal_moves!(board, pseudo, start, stop, moves, n_moves)

Filters pseudo-legal moves into legal moves, avoiding full make/undo
for moves that clearly cannot expose the king.
"""
function _filter_legal_moves!(board::Board, pseudo,
        start::Int, stop::Int,
        moves, n_moves::Int)
    side = board.side_to_move
    king_sq = king_square(board, side)
    occ = occupancy(board)
    in_check_now = in_check(board, side)

    @inbounds for i in start:stop
        m = pseudo[i]
        if is_move_legal(board, m, side, king_sq, occ, in_check_now)
            n_moves += 1
            moves[n_moves] = m
        end
    end
    return n_moves
end

function check_piece_moves!(board::Board, pseudo, pseudo_len, gen_func,
        side, king_sq, occ, in_check_now)
    old_len = pseudo_len
    pseudo_len = gen_func(board, pseudo, pseudo_len)

    @inbounds for i in old_len:(pseudo_len - 1)
        if is_move_legal(board, pseudo[i], side, king_sq, occ, in_check_now)
            return true, pseudo_len
        end
    end

    return false, pseudo_len
end

# Start with king if in check to find legal moves faster
const GEN_CHECKS_IN_CHECK = (generate_king_moves!, generate_knight_moves!,
    generate_pawn_moves!, generate_bishop_moves!,
    generate_rook_moves!, generate_queen_moves!)

const GEN_CHECKS_NORMAL = (generate_pawn_moves!, generate_knight_moves!,
    generate_king_moves!, generate_bishop_moves!,
    generate_rook_moves!, generate_queen_moves!)

function has_legal_move(board::Board)::Bool
    pseudo = MVector{MAX_MOVES, Move}(undef)
    side = board.side_to_move
    king_sq = king_square(board, side)
    occ = occupancy(board)
    in_check_now = in_check(board, side)

    pseudo_len = 1

    gens = in_check_now ? GEN_CHECKS_IN_CHECK : GEN_CHECKS_NORMAL
    @inbounds for gen_func in gens
        ok,
        pseudo_len = check_piece_moves!(
            board, pseudo, pseudo_len, gen_func, side, king_sq, occ, in_check_now)
        ok && return true
    end

    return false
end

# Public API
function generate_legal_moves!(board::Board, moves, pseudo)
    pseudo_len = 1
    pseudo_len = generate_pawn_moves!(board, pseudo, pseudo_len)
    pseudo_len = generate_knight_moves!(board, pseudo, pseudo_len)
    pseudo_len = generate_bishop_moves!(board, pseudo, pseudo_len)
    pseudo_len = generate_rook_moves!(board, pseudo, pseudo_len)
    pseudo_len = generate_queen_moves!(board, pseudo, pseudo_len)
    pseudo_len = generate_king_moves!(board, pseudo, pseudo_len)

    n_moves = 0
    # pseudo_len is one past the end
    n_moves = _filter_legal_moves!(board, pseudo, 1, pseudo_len - 1, moves, n_moves)
    return n_moves
end

function generate_legal_moves(board::Board)
    moves = Vector{Move}(undef, MAX_MOVES)  # Preallocate maximum possible moves
    pseudo = Vector{Move}(undef, MAX_MOVES) # Preallocate maximum possible moves
    n_moves = generate_legal_moves!(board, moves, pseudo)
    return moves[1:n_moves]  # Return only the filled portion
end

function generate_legal_moves_bishop_magic!(
        board::Board,
        moves,
        pseudo
)
    pseudo_len = 1

    pseudo_len = generate_pawn_moves!(board, pseudo, pseudo_len)
    pseudo_len = generate_knight_moves!(board, pseudo, pseudo_len)

    # Use magic bitboards for bishops
    pseudo_len = generate_bishop_moves_magic!(board, pseudo, pseudo_len)

    pseudo_len = generate_rook_moves!(board, pseudo, pseudo_len)
    pseudo_len = generate_queen_moves!(board, pseudo, pseudo_len)
    pseudo_len = generate_king_moves!(board, pseudo, pseudo_len)

    n_moves = 0
    # pseudo_len is one past the end
    n_moves = _filter_legal_moves!(board, pseudo, 1, pseudo_len - 1, moves, n_moves)

    return n_moves
end
