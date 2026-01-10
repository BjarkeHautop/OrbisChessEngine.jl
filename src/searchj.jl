using StaticArrays

const MATE_VALUE = 30_000
const MATE_THRESHOLD = 29_000  # threshold to consider a position as mate

const MAX_PLY = 128  # safe upper bound for typical search depth
const NO_MOVE = Move(0, 0, 0, 0, 0, false)
const KILLERS = [MVector{MAX_PLY, Move}(fill(NO_MOVE, MAX_PLY)) for _ in 1:MAX_PLY]

"""
Store a killer move for the given ply.
Only quiet moves (non-captures) are stored.
- m: the move to store
- ply: the current ply
"""
function store_killer!(m::Move, ply::Int)
    if m.capture == 0  # only quiet moves
        ply_idx = ply + 1
        if KILLERS[ply_idx][1] != m
            KILLERS[ply_idx][2] = KILLERS[ply_idx][1]
            KILLERS[ply_idx][1] = m
        end
    end
end

"""
    move_ordering_score(board::Board, m::Move, ply::Int)

Heuristic to score moves for ordering:
- Promotions are prioritized highest.
- Captures are prioritized higher.
- Moves giving check are prioritized.
- Quiet moves get a lower score.
"""
function move_ordering_score(board::Board, m::Move, ply::Int)
    score = 0
    capture_multiplier = 10
    in_check_bonus = 5000
    promotion_bonus = 8000
    killer_bonus = 4000

    # Killer move bonus (only quiet moves)
    if m.capture == 0 && (KILLERS[ply + 1][1] == m || KILLERS[ply + 1][2] == m)
        score += killer_bonus
    end

    # Captures: MVV-LVA
    if m.capture != 0
        attacker_piece = piece_at(board, m.from)
        capture_val = abs(PIECE_VALUES[m.capture])
        attacker_val = abs(PIECE_VALUES[attacker_piece])
        score += capture_val * capture_multiplier - attacker_val
    end

    # Bonus for checks
    make_move!(board, m)
    if in_check(board, board.side_to_move == WHITE ? BLACK : WHITE)
        score += in_check_bonus
    end

    # Bonus for promotions
    if m.promotion != 0
        score += abs(PIECE_VALUES[m.promotion]) + promotion_bonus
    end
    undo_move!(board, m)

    return score
end

# Types of stored nodes
@enum NodeType EXACT LOWERBOUND UPPERBOUND

"""
Transposition table entry.
- key: Zobrist hash of the position (for collision checking)
- value: evaluation score
- depth: search depth at which this value was computed
- node_type: type of node (EXACT, LOWERBOUND, UPPERBOUND)
- best_move: best move found from this position
"""
struct TTEntry
    key::UInt64
    value::Int
    depth::Int # -1 if empty
    node_type::NodeType
    best_move::Move
end

const TT_SIZE = 1 << 20  # ~1M entries
const TT_MASK = TT_SIZE - 1
const EMPTY_ENTRY = TTEntry(0, 0, -1, EXACT, NO_MOVE)
const TRANSPOSITION_TABLE = fill(EMPTY_ENTRY, TT_SIZE)

"""
Get index in transposition table from hash.
"""
@inline function tt_index(hash::UInt64)
    return hash & (TT_MASK) + 1  # mask for power-of-2 table
end

"""
Look up a position in the transposition table.
- hash: Zobrist hash of the position
- depth: current search depth
- α: alpha value
- β: beta value

Returns a tuple (value, best_move, hit) where hit is true if a valid entry was found.
"""
function tt_probe(hash::UInt64, depth::Int, α::Int, β::Int)
    idx = tt_index(hash)
    entry = TRANSPOSITION_TABLE[idx]

    # Check if slot is empty
    if entry.depth == -1
        return 0, NO_MOVE, false
    end

    # Check key and depth
    if entry.key != hash || entry.depth < depth
        return 0, NO_MOVE, false
    end

    # Return based on node type
    if entry.node_type == EXACT
        return entry.value, entry.best_move, true
    elseif entry.node_type == LOWERBOUND
        if entry.value >= β
            return entry.value, entry.best_move, true
        end
    elseif entry.node_type == UPPERBOUND
        if entry.value <= α
            return entry.value, entry.best_move, true
        end
    end

    # TT entry exists but cannot be used
    return 0, NO_MOVE, false
end

"""
Store an entry in the transposition table.
"""
function tt_store(
        hash::UInt64, value::Int, depth::Int, node_type::NodeType, best_move::Move)
    idx = tt_index(hash)
    entry = TRANSPOSITION_TABLE[idx]

    # Store if slot is empty (depth = -1) or new depth >= existing depth
    if entry.depth == -1 || depth >= entry.depth
        TRANSPOSITION_TABLE[idx] = TTEntry(hash, value, depth, node_type, best_move)
    end
end

# Quiescence search: only searches captures
const MAX_QUIESCENCE_PLY = 4
const moves_stack = [MVector{MAX_MOVES, Move}(undef) for _ in 1:(MAX_QUIESCENCE_PLY)]
const pseudo_stack = [MVector{MAX_MOVES, Move}(undef) for _ in 1:(MAX_QUIESCENCE_PLY)]

function quiescence(board::Board, α::Int, β::Int;
        ply::Int = 0
)
    side_to_move = board.side_to_move
    static_eval = evaluate(board)  # evaluation if we stop here

    if side_to_move == WHITE
        # White wants to maximize score
        if static_eval >= β
            return β   # beta cutoff
        end
        if static_eval > α
            α = static_eval
        end
    else
        # Black wants to minimize score
        if static_eval <= α
            return α   # alpha cutoff
        end
        if static_eval < β
            β = static_eval
        end
    end

    # Prevent runaway recursion in capture sequences
    if ply >= MAX_QUIESCENCE_PLY
        return static_eval
    end

    best_score = static_eval

    local_moves = moves_stack[ply + 1]      # safe per-ply buffer
    local_pseudo = pseudo_stack[ply + 1]

    n_moves = generate_captures!(board, local_moves, local_pseudo)

    @inbounds for i in 1:n_moves
        move = local_moves[i]
        make_move!(board, move)
        score = quiescence(board, α, β; ply = ply + 1)
        undo_move!(board, move)

        if side_to_move == WHITE
            if score > best_score
                best_score = score
            end
            if best_score > α
                α = best_score
            end
            if α >= β
                break
            end
        else
            if score < best_score
                best_score = score
            end
            if best_score < β
                β = best_score
            end
            if β <= α
                break
            end
        end
    end

    return best_score
end

function is_endgame(board::Board)
    # Consider endgame when phase < 5
    return board.game_phase_value < 5
end

"""
    SearchResult

Result of a search operation.

- `score`: The evaluation score of the position.
- `move`: The best move found.
- `from_book`: Boolean indicating if the move was from the opening book.
"""
struct SearchResult
    score::Int
    move::Move
    from_book::Bool
end

# Alpha-beta search with quiescence at leaves

const NULL_MOVE_REDUCTION = 2

function _search(
        board::Board,
        depth::Int,
        ply::Int,
        α::Int,
        β::Int,
        opening_book::Union{Nothing, PolyglotBook},
        stop_time::Int,
        moves_stack,
        pseudo_stack,
        score_stack
)::SearchResult

    # Time check
    if (time_ns() ÷ 1_000_000) >= stop_time
        return SearchResult(0, NO_MOVE, false)
    end

    # Opening book
    if opening_book !== nothing && ply == 0
        book_mv = book_move(board, opening_book)
        if book_mv !== nothing
            return SearchResult(0, book_mv, true)
        end
    end

    hash_before = zobrist_hash(board)

    # TT lookup
    val, move, hit = tt_probe(hash_before, depth, α, β)
    if hit
        return SearchResult(val, move, false)
    end

    # Leaf node: quiescence search
    if depth == 0
        return SearchResult(quiescence(board, α, β), NO_MOVE, false)
    end

    side_to_move = board.side_to_move

    # Seems to be broken? Disabling for now...
    # Null move pruning (only if endgame and not in check)
    # if (depth > NULL_MOVE_REDUCTION + 1) && is_endgame(board) &&
    #    !in_check(board, side_to_move)
    #     make_null_move!(board)
    #     result = _search(board, depth - 1 - NULL_MOVE_REDUCTION, ply + 1, -β, -β + 1,
    #         nothing, stop_time,
    #         moves_stack, pseudo_stack, score_stack)
    #     undo_null_move!(board)

    #     if side_to_move == WHITE && result.score >= β
    #         return SearchResult(result.score, NO_MOVE, false)
    #     elseif side_to_move == BLACK && result.score <= α
    #         return SearchResult(result.score, NO_MOVE, false)
    #     end
    # end

    moves = moves_stack[ply + 1]
    pseudo = pseudo_stack[ply + 1]
    scores = score_stack[ply + 1]

    n_moves = generate_legal_moves!(board, moves, pseudo)

    if n_moves == 0
        val = in_check(board, side_to_move) ?
              (side_to_move == WHITE ? -MATE_VALUE + ply : MATE_VALUE - ply) : 0
        return SearchResult(val, NO_MOVE, false)
    end

    # Precompute move scores
    @inbounds for i in 1:n_moves
        scores[i] = move_ordering_score(board, moves[i], ply)
    end

    best_score = board.side_to_move == WHITE ? -MATE_VALUE : MATE_VALUE
    best_move = NO_MOVE

    @inbounds for i in 1:n_moves
        # Find highest scoring remaining move
        best_idx = i
        best_val = scores[i]
        @inbounds for j in (i + 1):n_moves
            if scores[j] > best_val
                best_val = scores[j]
                best_idx = j
            end
        end

        if best_idx != i
            moves[i], moves[best_idx] = moves[best_idx], moves[i]
            scores[i], scores[best_idx] = scores[best_idx], scores[i]
        end

        m = moves[i]

        # Time check
        if (time_ns() ÷ 1_000_000) >= stop_time
            return SearchResult(best_score, best_move, false)
        end

        # Search child node
        make_move!(board, m)
        result = _search(board, depth - 1, ply + 1, α, β,
            opening_book, stop_time,
            moves_stack, pseudo_stack, score_stack)
        undo_move!(board, m)

        # Alpha-beta update
        if side_to_move == WHITE
            if result.score > best_score
                best_score = result.score
                best_move = m
                α = max(α, best_score)
                if best_score >= β
                    store_killer!(m, ply)
                    break
                end
            end
        else
            if result.score < best_score
                best_score = result.score
                best_move = m
                β = min(β, best_score)
                if best_score <= α
                    store_killer!(m, ply)
                    break
                end
            end
        end
    end

    # TT store
    node_type = EXACT
    if best_score <= α
        node_type = UPPERBOUND
    elseif best_score >= β
        node_type = LOWERBOUND
    end
    tt_store(hash_before, best_score, depth, node_type, best_move)

    return SearchResult(best_score, best_move, false)
end

function tt_probe_raw(hash::UInt64)
    idx = tt_index(hash)
    entry = TRANSPOSITION_TABLE[idx]

    if entry.depth != -1 && entry.key == hash
        return entry.value, entry.best_move, true
    else
        return 0, NO_MOVE, false
    end
end

"Reconstruct the principal variation (PV) from the transposition table"
function extract_root_pv(board::Board, root_move::Move, max_depth::Int)
    pv = Move[root_move]
    temp_board = deepcopy(board)
    make_move!(temp_board, root_move)

    for _ in 2:max_depth
        h = zobrist_hash(temp_board)
        val, move, hit = tt_probe_raw(h)
        if !hit || move === NO_MOVE
            break
        end
        push!(pv, move)
        make_move!(temp_board, move)
    end

    return pv
end

# Root-level iterative deepening search

function search_root(board::Board, max_depth::Int;
        opt_stop_time::Int = typemax(Int),
        max_stop_time::Int = typemax(Int),
        opening_book::Union{Nothing, PolyglotBook} = KOMODO_OPENING_BOOK,
        verbose::Bool = false
)::SearchResult
    # Use NO_MOVE as placeholder internally
    best_result_internal = SearchResult(0, NO_MOVE, false)

    moves_stack = [MVector{MAX_MOVES, Move}(undef) for _ in 1:(max_depth + 1)]
    pseudo_stack = [MVector{MAX_MOVES, Move}(undef) for _ in 1:(max_depth + 1)]
    score_stack = [MVector{MAX_MOVES, Int}(undef) for _ in 1:(max_depth + 1)]

    # Opening book probe
    if opening_book !== nothing
        book_mv = book_move(board, opening_book)
        if book_mv !== nothing
            if verbose
                println("Book move found: $book_mv")
            end
            # Return book move directly
            return SearchResult(0, book_mv, true)
        end
    end

    # --- Iterative deepening ---
    for depth in 1:max_depth
        if (time_ns() ÷ 1_000_000) >= max_stop_time
            break
        end

        result = _search(board, depth, 0, -MATE_VALUE, MATE_VALUE,
            opening_book, max_stop_time,
            moves_stack, pseudo_stack, score_stack)

        # Keep the internal best result
        if result.move !== NO_MOVE
            best_result_internal = result
        end

        if verbose
            pv = extract_root_pv(board, best_result_internal.move, depth)
            pv_str = join(string.(pv), " ")
            println("Depth $depth | Score: $(best_result_internal.score) | PV: $pv_str")
        end

        # Stop early if a mate is found
        if abs(best_result_internal.score) >= MATE_THRESHOLD
            if verbose
                mate_in = MATE_VALUE - abs(best_result_internal.score)
                println("Depth $depth | Score: Mate in $mate_in ply | PV: $pv_str")
            end

            break
        end

        now = time_ns() ÷ 1_000_000
        # --- Soft stop: if optimal time reached, stop after completed depth ---
        if now >= opt_stop_time
            break
        end
    end

    return SearchResult(best_result_internal.score, best_result_internal.move,
        best_result_internal.from_book)
end

"""
    search(
        board::Board;
        depth::Int,
        opening_book::Union{Nothing, PolyglotBook} = KOMODO_OPENING_BOOK,
        verbose::Bool = false,
        time_budget::Int = typemax(Int)
    )::SearchResult

Search for the best move using minimax with iterative deepening, alpha-beta pruning,
quiescence search, null move pruning, and transposition tables.

Arguments:
- `board`: current board position
- `depth`: search depth
- `opening_book`: if provided, uses a opening book. Default is `KOMODO_OPENING_BOOK`
taken from [free-opening-books](https://github.com/gmcheems-org/free-opening-books).
Set to `nothing` to disable. See [`load_polyglot_book`](@ref) to load custom books.
- `verbose`: if true, prints search information and principal variation (PV) at each depth
- `time_budget`: time in milliseconds to stop the search (if depth not reached)
Returns:
- `SearchResult` containing the best move and its evaluation score (or `nothing` if no move found)
"""
function search(
        board::Board;
        depth::Int,
        opening_book::Union{Nothing, PolyglotBook} = KOMODO_OPENING_BOOK,
        verbose::Bool = false,
        time_budget::Int = typemax(Int)
)
    tt_clear!()  # reset TT for this search
    tb = min(time_budget, 1_000_000_000)  # cap to 1e9 ms ~ 11 days
    stop_time = Int((time_ns() ÷ 1_000_000) + tb)
    result = search_root(board, depth; opt_stop_time = stop_time,
        max_stop_time = stop_time, opening_book = opening_book,
        verbose = verbose)

    # Convert NO_MOVE to nothing for public API
    if result.move === NO_MOVE
        if verbose
            println("No move found.")
        end
        return nothing
    else
        return result
    end
end

function tt_clear!()
    fill!(TRANSPOSITION_TABLE, EMPTY_ENTRY)
end
