const MAX_MOVES = 256  # 256 is safely larger than max legal moves:
# https://www.reddit.com/r/chess/comments/o4ajnn/whats_the_most_possible_legal_moves_in_a_chess/

using StaticArrays
"""
    perft(board::Board, depth::Int) -> Int

Compute the number of leaf nodes reachable from the given board position at the given depth.
It uses the Board struct to immitate [search](@ref) behavior. In particular,
this means it still computes zobrist hashes and updates evaluation scores
slowing it down compared to a minimal perft implementation.
"""
function perft(board::Board, depth::Int)
    moves_stack = [MVector{MAX_MOVES, Move}(undef) for _ in 1:(depth + 1)]
    pseudo_stack = [MVector{MAX_MOVES, Move}(undef) for _ in 1:(depth + 1)]

    return _perft!(board, depth, moves_stack, pseudo_stack, 1)
end

function _perft!(
        board::Board,
        depth::Int,
        moves_stack,
        pseudo_stack,
        level::Int
)
    if depth == 0
        return 1
    end

    nodes = 0
    moves = moves_stack[level]
    pseudo = pseudo_stack[level]

    n_moves = generate_legal_moves!(board, moves, pseudo)

    # 3% faster with @inbounds here
    @inbounds for i in 1:n_moves
        move = moves[i]
        make_move!(board, move)
        nodes += _perft!(board, depth - 1, moves_stack, pseudo_stack, level + 1)
        undo_move!(board, move)
    end

    return nodes
end

using Base.Threads

function split_indices(nmoves, nthreads)
    chunk_sizes = fill(div(nmoves, nthreads), nthreads)
    for i in 1:rem(nmoves, nthreads)
        chunk_sizes[i] += 1
    end

    chunks = Vector{UnitRange{Int}}(undef, nthreads)
    start = 1
    for i in 1:nthreads
        stop = start + chunk_sizes[i] - 1
        chunks[i] = start:stop
        start = stop + 1
    end
    return chunks
end

"""
    perft_fast(board::Board, depth::Int) -> Int

Compute the number of leaf nodes reachable from the given board position at the given depth
using multiple threads at the root.
It uses the Board struct to immitate [search](@ref) behavior. In particular,
this means it still computes zobrist hashes and updates evaluation scores
slowing it down compared to a minimal perft implementation.
"""
function perft_fast(board::Board, depth::Int)
    if depth == 0
        return 1
    end

    moves_stack = [MVector{MAX_MOVES, Move}(undef) for _ in 1:(depth + 1)]
    pseudo_stack = [MVector{MAX_MOVES, Move}(undef) for _ in 1:(depth + 1)]

    root_moves = moves_stack[1]
    root_pseudo = pseudo_stack[1]
    n_moves = generate_legal_moves!(board, root_moves, root_pseudo)

    nthreads_ = min(n_moves, Threads.nthreads())
    chunks = split_indices(n_moves, nthreads_)

    futures = Vector{Task}(undef, nthreads_)
    for t in 1:nthreads_
        range = chunks[t]
        futures[t] = Threads.@spawn begin
            local_board = deepcopy(board)  # thread-local board
            local_moves_stack = [MVector{MAX_MOVES, Move}(undef) for _ in 1:(depth + 1)]
            local_pseudo_stack = [MVector{MAX_MOVES, Move}(undef) for _ in 1:(depth + 1)]

            nodes = 0
            for i in range
                move = root_moves[i]
                make_move!(local_board, move)
                nodes += _perft!(
                    local_board, depth - 1, local_moves_stack, local_pseudo_stack, 2)
                undo_move!(local_board, move)
            end
            return nodes
        end
    end

    return sum(fetch.(futures))
end

function perft_bishop_magic(board::Board, depth::Int)
    moves_stack = [MVector{MAX_MOVES, Move}(undef) for _ in 1:(depth + 1)]
    pseudo_stack = [MVector{MAX_MOVES, Move}(undef) for _ in 1:(depth + 1)]

    return _perft_bishop_magic!(board, depth, moves_stack, pseudo_stack, 1)
end

function _perft_bishop_magic!(
        board::Board,
        depth::Int,
        moves_stack,
        pseudo_stack,
        level::Int
)
    if depth == 0
        return 1
    end

    nodes = 0
    moves = moves_stack[level]
    pseudo = pseudo_stack[level]

    n_moves = generate_legal_moves_bishop_magic!(board, moves, pseudo)

    @inbounds for i in 1:n_moves
        move = moves[i]
        make_move!(board, move)
        nodes += _perft_bishop_magic!(
            board, depth - 1, moves_stack, pseudo_stack, level + 1)
        undo_move!(board, move)
    end

    return nodes
end

# Could consider making a minimal board struct for faster perft (no eval, no zobrist,
# no history, smaller preallocated arrays, etc.).
