# Piece values for move ordering
const PIECE_VALUES = Dict(
    Piece.W_PAWN => 100,
    Piece.B_PAWN => -100,
    Piece.W_KNIGHT => 300,
    Piece.B_KNIGHT => -300,
    Piece.W_BISHOP => 300,
    Piece.B_BISHOP => -300,
    Piece.W_ROOK => 500,
    Piece.B_ROOK => -500,
    Piece.W_QUEEN => 1000,
    Piece.B_QUEEN => -1000,
    Piece.W_KING => 0,
    Piece.B_KING => 0
)

# material weight used for phase calculation
function phase_weight(p)
    (p == Piece.W_QUEEN || p == Piece.B_QUEEN) ? 4 :
    (p == Piece.W_ROOK || p == Piece.B_ROOK) ? 2 :
    (p == Piece.W_BISHOP || p == Piece.B_BISHOP ||
     p == Piece.W_KNIGHT || p == Piece.B_KNIGHT) ? 1 : 0
end

# Mobility: centipawns per square a piece attacks/could move to (excluding
# squares occupied by its own side). Untuned, deliberately conservative
# defaults — see item 8 in TODO.md, no automated tuning infrastructure
# exists in this repo yet.
const KNIGHT_MOBILITY_WEIGHT = 4
const BISHOP_MOBILITY_WEIGHT = 3
const ROOK_MOBILITY_WEIGHT = 2
const QUEEN_MOBILITY_WEIGHT = 1

# King safety: centipawn weight contributed by each enemy piece attacking a
# square in the king's zone (its own square and its 8 neighbors) — pieces
# that hit the zone more than once still only count once. The accumulated
# weight is squared (capped) rather than applied linearly, since a single
# attacker is only mildly dangerous but several together are much worse
# than the sum of their parts.
const KNIGHT_KING_ATTACK_WEIGHT = 2
const BISHOP_KING_ATTACK_WEIGHT = 2
const ROOK_KING_ATTACK_WEIGHT = 3
const QUEEN_KING_ATTACK_WEIGHT = 5
const KING_SAFETY_MAX_PENALTY = 400

# Pawn shield: a king still on its own back two ranks (i.e. not yet
# centralized for an endgame) is penalized for each of the 3 files around
# it that doesn't have an own pawn one rank ahead. Deliberately simple —
# the rank check alone makes this fade out naturally once the king
# advances later in the game.
const PAWN_SHIELD_PENALTY = 20

@inline function knight_term(bb::UInt64, own_occ::UInt64, enemy_king_zone::UInt64)
    mobility = 0
    king_attackers = 0
    while bb != 0
        sq = trailing_zeros(bb)
        bb &= bb - 1
        atk = knight_attack_masks[sq + 1]
        mobility += count_ones(atk & ~own_occ)
        if (atk & enemy_king_zone) != 0
            king_attackers += 1
        end
    end
    return mobility, king_attackers
end

@inline function slider_term(
        bb::UInt64, occ::UInt64, own_occ::UInt64, enemy_king_zone::UInt64, directions)
    mobility = 0
    king_attackers = 0
    while bb != 0
        sq = trailing_zeros(bb)
        bb &= bb - 1
        atk = sliding_attack_from_occupancy(sq, occ, directions)
        mobility += count_ones(atk & ~own_occ)
        if (atk & enemy_king_zone) != 0
            king_attackers += 1
        end
    end
    return mobility, king_attackers
end

@inline function queen_term(bb::UInt64, occ::UInt64, own_occ::UInt64, enemy_king_zone::UInt64)
    mobility = 0
    king_attackers = 0
    while bb != 0
        sq = trailing_zeros(bb)
        bb &= bb - 1
        atk = sliding_attack_from_occupancy(sq, occ, ROOK_DIRECTIONS) |
              sliding_attack_from_occupancy(sq, occ, BISHOP_DIRECTIONS)
        mobility += count_ones(atk & ~own_occ)
        if (atk & enemy_king_zone) != 0
            king_attackers += 1
        end
    end
    return mobility, king_attackers
end

"""
    mobility_and_king_safety(board::Board) -> Int

Mobility and king-safety term for `evaluate`, from White's point of view.
Each minor/major piece's attack bitboard is computed once and used both for
its own side's mobility score and (if it reaches into the enemy king's
zone) the enemy king's attacker weight.
"""
function mobility_and_king_safety(board::Board)
    occ = zero(UInt64)
    for p in ALL_PIECES
        occ |= board.bitboards[p]
    end
    white_occ = zero(UInt64)
    for p in WHITE_PIECES
        white_occ |= board.bitboards[p]
    end
    black_occ = occ & ~white_occ

    white_king_zone = king_attack_masks[king_square(board, WHITE) + 1]
    black_king_zone = king_attack_masks[king_square(board, BLACK) + 1]

    wn_mob, wn_katk = knight_term(board.bitboards[Piece.W_KNIGHT], white_occ, black_king_zone)
    bn_mob, bn_katk = knight_term(board.bitboards[Piece.B_KNIGHT], black_occ, white_king_zone)

    wb_mob, wb_katk = slider_term(
        board.bitboards[Piece.W_BISHOP], occ, white_occ, black_king_zone, BISHOP_DIRECTIONS)
    bb_mob, bb_katk = slider_term(
        board.bitboards[Piece.B_BISHOP], occ, black_occ, white_king_zone, BISHOP_DIRECTIONS)

    wr_mob, wr_katk = slider_term(
        board.bitboards[Piece.W_ROOK], occ, white_occ, black_king_zone, ROOK_DIRECTIONS)
    br_mob, br_katk = slider_term(
        board.bitboards[Piece.B_ROOK], occ, black_occ, white_king_zone, ROOK_DIRECTIONS)

    wq_mob, wq_katk = queen_term(board.bitboards[Piece.W_QUEEN], occ, white_occ, black_king_zone)
    bq_mob, bq_katk = queen_term(board.bitboards[Piece.B_QUEEN], occ, black_occ, white_king_zone)

    score = KNIGHT_MOBILITY_WEIGHT * (wn_mob - bn_mob) +
            BISHOP_MOBILITY_WEIGHT * (wb_mob - bb_mob) +
            ROOK_MOBILITY_WEIGHT * (wr_mob - br_mob) +
            QUEEN_MOBILITY_WEIGHT * (wq_mob - bq_mob)

    white_king_weight = bn_katk * KNIGHT_KING_ATTACK_WEIGHT +
                        bb_katk * BISHOP_KING_ATTACK_WEIGHT +
                        br_katk * ROOK_KING_ATTACK_WEIGHT +
                        bq_katk * QUEEN_KING_ATTACK_WEIGHT
    black_king_weight = wn_katk * KNIGHT_KING_ATTACK_WEIGHT +
                        wb_katk * BISHOP_KING_ATTACK_WEIGHT +
                        wr_katk * ROOK_KING_ATTACK_WEIGHT +
                        wq_katk * QUEEN_KING_ATTACK_WEIGHT

    score -= min(white_king_weight^2, KING_SAFETY_MAX_PENALTY)
    score += min(black_king_weight^2, KING_SAFETY_MAX_PENALTY)

    return score
end

"""
    pawn_shield_score(board::Board) -> Int

Penalize a king still on its own back two ranks for missing pawns on the
3 files around it, one rank ahead.
"""
function pawn_shield_score(board::Board)
    score = 0

    wk = king_square(board, WHITE)
    wf, wr = file_rank(wk)
    if wr <= 2
        for f in max(1, wf - 1):min(8, wf + 1)
            shield_sq = square_index(f, wr + 1)
            if !testbit(board.bitboards[Piece.W_PAWN], shield_sq)
                score -= PAWN_SHIELD_PENALTY
            end
        end
    end

    bk = king_square(board, BLACK)
    bf, br = file_rank(bk)
    if br >= 7
        for f in max(1, bf - 1):min(8, bf + 1)
            shield_sq = square_index(f, br - 1)
            if !testbit(board.bitboards[Piece.B_PAWN], shield_sq)
                score += PAWN_SHIELD_PENALTY
            end
        end
    end

    return score
end

"""
    evaluate(board::Board) -> Int

Evaluate a position from White’s perspective using piece-square tables.

Purely a static material+PST sum — it does **not** check for checkmate,
stalemate, or draws (that used to call `game_status`, which generates legal
moves; doing that on every call was catastrophically expensive since this
runs at every quiescence node). Checkmate/stalemate/draw detection is
`_search`'s responsibility, since it already generates legal moves for every
node it visits regardless.
- board: Board struct

# Example
```julia
board = Board()
evaluate(board)
````
"""
function evaluate(board::Board)
    score = 0
    for (p, bb) in enumerate(board.bitboards)
        while bb != 0
            square = trailing_zeros(bb)  # index of least significant 1-bit (0..63)
            score += piece_square_value(p, square, board.game_phase_value)
            bb &= bb - 1  # clear that bit
        end
    end
    score += mobility_and_king_safety(board)
    score += pawn_shield_score(board)
    return score
end

"""
    compute_eval_and_phase(board::Board) -> (Int, Int)

Compute the evaluation score (from White's perspective) and the game phase value
from scratch for a given board.
"""
function compute_eval_and_phase(board::Board)
    eval_score = 0
    game_phase_value = 0

    for (piece, bb) in enumerate(board.bitboards)
        while bb != 0
            sq = trailing_zeros(bb)
            bb &= bb - 1

            game_phase_value += phase_weight(piece)
        end
    end

    # Now compute evaluation using that phase
    for (piece, bb) in enumerate(board.bitboards)
        tmp_bb = bb
        while tmp_bb != 0
            sq = trailing_zeros(tmp_bb)
            tmp_bb &= tmp_bb - 1
            eval_score += piece_square_value(piece, sq, game_phase_value)
        end
    end

    return eval_score, game_phase_value
end
