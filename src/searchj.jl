using StaticArrays

const MATE_VALUE = 30_000
const MATE_THRESHOLD = 29_000  # threshold to consider a position as mate

const MAX_PLY = 128  # safe upper bound for typical search depth
const NO_MOVE = Move(0, 0, 0, 0, 0, false)
const KILLERS = [MVector{MAX_PLY, Move}(fill(NO_MOVE, MAX_PLY)) for _ in 1:MAX_PLY]

# History heuristic: [side_to_move (1=WHITE,2=BLACK), from+1, to+1] -> score.
# Tracks which quiet (from,to) moves have historically caused beta cutoffs,
# independent of ply/position (unlike KILLERS, which is ply-specific).
# Clamped at HISTORY_MAX so a heavily-reinforced entry still ranks below a
# killer-move bonus in move_ordering_score.
const HISTORY_MAX = 3000
const HISTORY = zeros(Int, 2, 64, 64)

# Node counter for diagnostics (UCI "info ... nodes ... nps ..."). Reset at
# the start of every search() call.
const NODE_COUNT = Ref(0)

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
Update the history heuristic for a quiet move that caused a beta cutoff.
Only quiet (non-capture) moves are tracked — captures already order via
MVV-LVA. Score is bumped by `depth^2` (moves that caused cutoffs deeper in
the tree are weighted more heavily), clamped at `HISTORY_MAX`.
- side: the side that made the move
- m: the move to reward
- depth: remaining search depth at the node where the cutoff occurred
"""
function update_history!(side::Side, m::Move, depth::Int)
    if m.capture == 0  # only quiet moves
        side_idx = Int(side) + 1
        HISTORY[side_idx, m.from + 1, m.to + 1] = min(
            HISTORY[side_idx, m.from + 1, m.to + 1] + depth * depth, HISTORY_MAX)
    end
end

"""
    move_ordering_score(board::Board, m::Move, ply::Int)

Heuristic to score moves for ordering:
- Promotions are prioritized highest.
- Captures are prioritized higher.
- Moves giving check are prioritized.
- Killer moves (quiet moves that caused a cutoff at this ply before) next.
- Other quiet moves are ordered by the history heuristic.
"""
function move_ordering_score(board::Board, m::Move, ply::Int)
    score = 0
    capture_multiplier = 10
    in_check_bonus = 5000
    promotion_bonus = 8000
    killer_bonus = 4000

    # Killer move bonus, else history heuristic score (both quiet-move only)
    if m.capture == 0
        if KILLERS[ply + 1][1] == m || KILLERS[ply + 1][2] == m
            score += killer_bonus
        else
            score += HISTORY[Int(board.side_to_move) + 1, m.from + 1, m.to + 1]
        end
    end

    # Captures: MVV-LVA
    if m.capture != 0
        attacker_piece = piece_at(board, m.from)
        capture_val = abs(PIECE_VALUES[m.capture])
        attacker_val = abs(PIECE_VALUES[attacker_piece])
        score += capture_val * capture_multiplier - attacker_val
    end

    # Bonus for checks.
    make_move!(board, m)
    if in_check(board, board.side_to_move)
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

# Mate scores (abs(score) >= MATE_THRESHOLD) encode plies-from-search-root,
# so they can't be reused as-is when the same position transposes in at a
# different ply. Re-anchor to the position itself (ply-agnostic) on store,
# and back to the current root on retrieval.
@inline function mate_score_to_tt(score::Int, ply::Int)
    if score >= MATE_THRESHOLD
        return score + ply
    elseif score <= -MATE_THRESHOLD
        return score - ply
    end
    return score
end

@inline function mate_score_from_tt(score::Int, ply::Int)
    if score >= MATE_THRESHOLD
        return score - ply
    elseif score <= -MATE_THRESHOLD
        return score + ply
    end
    return score
end

"""
Look up a position in the transposition table.
- hash: Zobrist hash of the position
- depth: current search depth
- α: alpha value
- β: beta value
- ply: current node's distance from this search's root

Returns a tuple (value, best_move, hit) where hit is true if a valid entry was found.
"""
function tt_probe(hash::UInt64, depth::Int, α::Int, β::Int, ply::Int = 0)
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

    value = mate_score_from_tt(entry.value, ply)

    # Return based on node type
    if entry.node_type == EXACT
        return value, entry.best_move, true
    elseif entry.node_type == LOWERBOUND
        if value >= β
            return value, entry.best_move, true
        end
    elseif entry.node_type == UPPERBOUND
        if value <= α
            return value, entry.best_move, true
        end
    end

    # TT entry exists but cannot be used
    return 0, NO_MOVE, false
end

"""
Store an entry in the transposition table.
- ply: current node's distance from this search's root
"""
function tt_store(
        hash::UInt64, value::Int, depth::Int, node_type::NodeType, best_move::Move,
        ply::Int = 0)
    idx = tt_index(hash)
    entry = TRANSPOSITION_TABLE[idx]
    value = mate_score_to_tt(value, ply)

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
    NODE_COUNT[] += 1
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
- `complete`: `false` if this node was cut short by the time budget before
  finishing — such results must never be compared or trusted as real values.
"""
struct SearchResult
    score::Int
    move::Move
    from_book::Bool
    complete::Bool
end

# Alpha-beta search with quiescence at leaves

const NULL_MOVE_REDUCTION = 2

# Late Move Reductions: quiet moves searched late in a node's move list (i.e.
# after move ordering has already tried the moves most likely to be good)
# are searched at reduced depth first. If a reduced search unexpectedly
# fails high, it's re-searched at full depth — see the PVS re-search
# comment below, which LMR reuses to verify a reduction was safe.
const LMR_MIN_DEPTH = 3          # only reduce when there's depth to spare
const LMR_FULL_DEPTH_MOVES = 3   # first N moves at a node are never reduced
const LMR_REDUCTION = 1          # plies shaved off a reduced search

# Reverse futility pruning (aka static null move pruning): at shallow
# remaining depth, if the static eval already clears β (or α, for Black) by
# more than `depth` plies of real search could plausibly claw back, assume
# a real move only does at least as well and skip the node entirely.
const RFP_MAX_DEPTH = 6
const RFP_MARGIN_PER_PLY = 100

# Futility pruning: same idea as RFP, but applied per quiet move inside the
# move loop instead of to the whole node — skip a move outright if even its
# best-case swing (static eval + a depth-scaled margin) can't plausibly
# change the outcome. Never applied to the first (best-ordered) move.
const FUTILITY_MAX_DEPTH = 3
const FUTILITY_MARGIN_PER_PLY = 150

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
    NODE_COUNT[] += 1

    # Time check. Nothing has been evaluated at this node yet, so there's no
    # real score to report — `complete = false` tells the caller not to
    # treat this as a trustworthy value.
    if (time_ns() ÷ 1_000_000) >= stop_time
        return SearchResult(0, NO_MOVE, false, false)
    end

    # Opening book
    if opening_book !== nothing && ply == 0
        book_mv = book_move(board, opening_book)
        if book_mv !== nothing
            return SearchResult(0, book_mv, true, true)
        end
    end

    hash_before = zobrist_hash(board)

    # TT lookup
    val, move, hit = tt_probe(hash_before, depth, α, β, ply)
    if hit
        return SearchResult(val, move, false, true)
    end

    # Leaf node: quiescence search
    if depth == 0
        return SearchResult(quiescence(board, α, β), NO_MOVE, false, true)
    end

    side_to_move = board.side_to_move
    own_in_check = in_check(board, side_to_move)
    board_is_endgame = is_endgame(board)

    # Both static-eval-based prunings below (reverse futility here, and
    # futility per-move in the move loop) rest on the same assumption: at
    # shallow remaining depth, a position already far enough beyond α/β
    # doesn't need real search to know its outcome. Both share one static
    # eval call and the same unsoundness guards as null-move pruning:
    # skipped in check (tactical, unstable position), in the endgame
    # (zugzwang breaks the "some move is at least this good" assumption),
    # and near mate scores (static eval is never mate-range, so this guard
    # is mostly redundant, but cheap insurance against interfering with
    # this file's mate-score handling).
    can_prune_statically = !own_in_check && !board_is_endgame &&
                           abs(α) < MATE_THRESHOLD && abs(β) < MATE_THRESHOLD
    static_eval = 0
    if can_prune_statically && depth <= max(RFP_MAX_DEPTH, FUTILITY_MAX_DEPTH)
        static_eval = evaluate(board)

        if depth <= RFP_MAX_DEPTH
            margin = RFP_MARGIN_PER_PLY * depth
            if side_to_move == WHITE && static_eval - margin >= β
                return SearchResult(static_eval, NO_MOVE, false, true)
            elseif side_to_move == BLACK && static_eval + margin <= α
                return SearchResult(static_eval, NO_MOVE, false, true)
            end
        end
    end

    # Null move pruning: a free pass that still fails high/low means the
    # position is good enough that a real move only does better. Skipped in
    # the endgame (zugzwang) and while in check (no null move is legal).
    # `result.complete` guards against trusting a subsearch cut short by the
    # time budget, same as everywhere else in this function.
    if (depth > NULL_MOVE_REDUCTION + 1) && !board_is_endgame && !own_in_check
        make_null_move!(board)
        null_α, null_β = side_to_move == WHITE ? (β - 1, β) : (α, α + 1)
        result = _search(board, depth - 1 - NULL_MOVE_REDUCTION, ply + 1, null_α, null_β,
            nothing, stop_time,
            moves_stack, pseudo_stack, score_stack)
        undo_null_move!(board)

        if result.complete
            if side_to_move == WHITE && result.score >= β
                return SearchResult(result.score, NO_MOVE, false, true)
            elseif side_to_move == BLACK && result.score <= α
                return SearchResult(result.score, NO_MOVE, false, true)
            end
        end
    end

    moves = moves_stack[ply + 1]
    pseudo = pseudo_stack[ply + 1]
    scores = score_stack[ply + 1]

    n_moves = generate_legal_moves!(board, moves, pseudo)

    if n_moves == 0
        val = in_check(board, side_to_move) ?
              (side_to_move == WHITE ? -MATE_VALUE + ply : MATE_VALUE - ply) : 0
        return SearchResult(val, NO_MOVE, false, true)
    end

    # Draw detection: after move gen (free, already done) and after
    # mate/stalemate (higher priority); not inside evaluate(), which runs
    # per quiescence node.
    if is_insufficient_material(board) || is_threefold_repetition(board) ||
       is_fifty_move_rule(board)
        return SearchResult(0, NO_MOVE, false, true)
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

        # A partial comparison across some but not all sibling moves is
        # never a trustworthy minimax value, regardless of best_move.
        if (time_ns() ÷ 1_000_000) >= stop_time
            return SearchResult(best_score, best_move, false, false)
        end

        # Futility pruning: skip a quiet move at shallow depth whose
        # best-case swing still can't plausibly change this node's outcome.
        # Never applied to the first (best-ordered) move — same reasoning
        # as LMR not reducing it.
        if can_prune_statically && depth <= FUTILITY_MAX_DEPTH && i > 1 &&
           m.capture == 0 && m.promotion == 0
            margin = FUTILITY_MARGIN_PER_PLY * depth
            if side_to_move == WHITE && static_eval + margin <= α
                continue
            elseif side_to_move == BLACK && static_eval - margin >= β
                continue
            end
        end

        # Search child node. The first move gets a full-window search (it's
        # the PV candidate); later moves are searched with PVS + LMR:
        # - PVS: scout with a 1-point-wide null window at full depth. A
        #   null window only proves whether the true score is above/below
        #   it, not the exact value, but that's all we need for moves we
        #   expect to fail low (i.e. not beat the current best) — and it's
        #   cheaper to prove than to compute exactly. If the scout instead
        #   fails high, the move may really be better, so re-search with
        #   the true (α, β) window to get an exact, trustworthy score.
        # - LMR: quiet moves late in the (already ordered, so presumably
        #   less promising) move list, at a node not itself evading check,
        #   get the null-window scout above tried at reduced depth first;
        #   only if *that* fails high is it re-verified at full depth
        #   before potentially falling through to the full-window re-search.
        make_move!(board, m)

        if i == 1
            result = _search(board, depth - 1, ply + 1, α, β,
                opening_book, stop_time,
                moves_stack, pseudo_stack, score_stack)
        else
            reduce = depth >= LMR_MIN_DEPTH && i > LMR_FULL_DEPTH_MOVES &&
                     m.capture == 0 && m.promotion == 0 && !own_in_check
            r = reduce ? LMR_REDUCTION : 0
            null_α, null_β = side_to_move == WHITE ? (α, α + 1) : (β - 1, β)

            result = _search(board, depth - 1 - r, ply + 1, null_α, null_β,
                opening_book, stop_time,
                moves_stack, pseudo_stack, score_stack)

            # Reduced scout looked better than expected — verify at full
            # depth (still null window) before trusting it.
            if result.complete && r > 0 &&
               ((side_to_move == WHITE && result.score > α) ||
                (side_to_move == BLACK && result.score < β))
                result = _search(board, depth - 1, ply + 1, null_α, null_β,
                    opening_book, stop_time,
                    moves_stack, pseudo_stack, score_stack)
            end

            # Null-window result landed strictly inside (α, β): it's a real
            # improvement but the narrow window can't tell us by how much —
            # re-search with the true window for an exact score.
            if result.complete && α < result.score < β
                result = _search(board, depth - 1, ply + 1, α, β,
                    opening_book, stop_time,
                    moves_stack, pseudo_stack, score_stack)
            end
        end

        undo_move!(board, m)

        if !result.complete
            # Child was cut short by the time budget — abort this node too
            # instead of comparing against an untrustworthy score.
            return SearchResult(best_score, best_move, false, false)
        end

        # Alpha-beta update
        if side_to_move == WHITE
            if result.score > best_score
                best_score = result.score
                best_move = m
                α = max(α, best_score)
                if best_score >= β
                    store_killer!(m, ply)
                    update_history!(side_to_move, m, depth)
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
                    update_history!(side_to_move, m, depth)
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
    tt_store(hash_before, best_score, depth, node_type, best_move, ply)

    return SearchResult(best_score, best_move, false, true)
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

"""
Print a UCI "info" line for the given depth's result: score (relative to the
side to move, per the UCI spec), elapsed time, node count/rate, and PV in
UCI notation.
"""
function uci_info_line(
        depth::Int, score::Int, pv::Vector{Move}, side_to_move::Side, start_ms::Int)
    elapsed = max(1, (time_ns() ÷ 1_000_000) - start_ms)
    nodes = NODE_COUNT[]
    nps = (nodes * 1000) ÷ elapsed
    pv_str = join(to_uci.(pv), " ")

    stm_score = side_to_move == WHITE ? score : -score
    score_str = if abs(score) >= MATE_THRESHOLD
        mate_plies = MATE_VALUE - abs(score)
        mate_moves = cld(mate_plies, 2)
        "mate $(stm_score < 0 ? -mate_moves : mate_moves)"
    else
        "cp $stm_score"
    end

    println("info depth $depth score $score_str time $elapsed nodes $nodes " *
            "nps $nps pv $pv_str")
end

# Panic extension: a depth that scores this much worse (centipawns, for the
# side to move) than the previous depth, or changes its mind about the best
# move, hasn't converged — worth extending past the soft limit for instead
# of committing to a possibly-bad move on schedule.
const PANIC_SCORE_DROP = 50

function search_root(board::Board, max_depth::Int;
        opt_stop_time::Int = typemax(Int),
        max_stop_time::Int = typemax(Int),
        opening_book::Union{Nothing, PolyglotBook} = KOMODO_OPENING_BOOK,
        verbose::Bool = false,
        uci_info::Bool = false
)::SearchResult
    search_start = Int(time_ns() ÷ 1_000_000)
    # Use NO_MOVE as placeholder internally
    best_result_internal = SearchResult(0, NO_MOVE, false, false)
    # Last-resort fallback if no depth ever completes: better than no move.
    fallback_result = SearchResult(0, NO_MOVE, false, false)
    prev_score = nothing
    prev_move = NO_MOVE

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
            return SearchResult(0, book_mv, true, true)
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

        if result.move !== NO_MOVE
            fallback_result = result
        end

        # Only adopt a depth once it's complete — never a time-budget cutoff.
        unstable = false
        if result.complete && result.move !== NO_MOVE
            if prev_score !== nothing
                worse_for_stm = board.side_to_move == WHITE ?
                                result.score < prev_score - PANIC_SCORE_DROP :
                                result.score > prev_score + PANIC_SCORE_DROP
                unstable = worse_for_stm || result.move != prev_move
            end
            prev_score = result.score
            prev_move = result.move
            best_result_internal = result
        end

        if result.complete && result.move !== NO_MOVE && (verbose || uci_info)
            pv = extract_root_pv(board, best_result_internal.move, depth)

            if verbose
                pv_str = join(string.(pv), " ")
                println("Depth $depth | Score: $(best_result_internal.score) | PV: $pv_str")
            end

            if uci_info
                uci_info_line(depth, best_result_internal.score, pv,
                    board.side_to_move, search_start)
            end
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
        # Soft stop: once optimal time is reached, stop after the current
        # depth — unless it looks unstable, in which case keep going (still
        # bounded by max_stop_time above and _search's own per-node check).
        if now >= opt_stop_time && !unstable
            break
        end
    end

    # Fall back to the best partial result only if no depth ever completed.
    return best_result_internal.move !== NO_MOVE ? best_result_internal : fallback_result
end

"""
    search(
        board::Board;
        depth::Int,
        opening_book::Union{Nothing, PolyglotBook} = KOMODO_OPENING_BOOK,
        verbose::Bool = false,
        uci_info::Bool = false,
        time_budget::Int = typemax(Int),
        max_time_budget::Int = time_budget
    )::SearchResult

Search for the best move using minimax with iterative deepening, alpha-beta pruning,
quiescence search, null move pruning, and transposition tables.

Arguments:
- `board`: current board position
- `depth`: search depth
- `opening_book`: if provided, uses a opening book. Default is `KOMODO_OPENING_BOOK`
taken from [free-opening-books](https://github.com/gmcheems-org/free-opening-books).
Set to `nothing` to disable. See [`load_polyglot_book`](@ref) to load custom books.
- `verbose`: if true, prints human-readable search information and principal
  variation (PV) at each depth
- `uci_info`: if true, prints a UCI-style `info depth ... score ... time ...
  nodes ... nps ... pv ...` line at each depth (score is relative to the side
  to move, per the UCI spec, unlike the always-White-relative `score` field
  on the returned `SearchResult`)
- `time_budget`: soft time limit in milliseconds — the search stops after
  the current depth *finishes* once this is reached, unless the result
  looks unstable (see `search_root`), in which case it keeps going up to
  `max_time_budget`
- `max_time_budget`: hard time limit in milliseconds; can cut a depth off
  mid-search. Defaults to `time_budget` (no extension allowed)
Returns:
- `SearchResult` containing the best move and its evaluation score (or `nothing` if no move found)

# Example
```julia
board = Board()
search(board; depth=5, opening_book=nothing, verbose=true, time_budget=5000)
```
"""
function search(
        board::Board;
        depth::Int,
        opening_book::Union{Nothing, PolyglotBook} = KOMODO_OPENING_BOOK,
        verbose::Bool = false,
        uci_info::Bool = false,
        time_budget::Int = typemax(Int),
        max_time_budget::Int = time_budget
)
    tt_clear!()  # reset TT for this search
    NODE_COUNT[] = 0
    now = time_ns() ÷ 1_000_000
    opt_stop_time = Int(now + min(time_budget, 1_000_000_000))  # cap to 1e9 ms ~ 11 days
    max_stop_time = Int(now + min(max(max_time_budget, time_budget), 1_000_000_000))
    result = search_root(board, depth; opt_stop_time = opt_stop_time,
        max_stop_time = max_stop_time, opening_book = opening_book,
        verbose = verbose, uci_info = uci_info)
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
