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
    Piece.B_KING => 0,
)

# material weight used for phase calculation
function phase_weight(p)
    (p == Piece.W_QUEEN || p == Piece.B_QUEEN) ? 4 :
    (p == Piece.W_ROOK || p == Piece.B_ROOK) ? 2 :
    (
        p == Piece.W_BISHOP ||
        p == Piece.B_BISHOP ||
        p == Piece.W_KNIGHT ||
        p == Piece.B_KNIGHT
    ) ? 1 : 0
end

# Mobility: centipawns per square a piece attacks/could move to (excluding
# squares occupied by its own side).
const KNIGHT_MOBILITY_WEIGHT = 4
const BISHOP_MOBILITY_WEIGHT = 3
const ROOK_MOBILITY_WEIGHT = 2
const QUEEN_MOBILITY_WEIGHT = 1

# King safety: centipawn weight contributed by each enemy piece attacking a
# square in the king's zone (its own square and its 8 neighbors).
# The accumulated weight is squared, since several attackers are much worse.
const KNIGHT_KING_ATTACK_WEIGHT = 2
const BISHOP_KING_ATTACK_WEIGHT = 2
const ROOK_KING_ATTACK_WEIGHT = 3
const QUEEN_KING_ATTACK_WEIGHT = 5
const KING_SAFETY_MAX_PENALTY = 400

# Pawn shield: a king still on its own back two ranks is penalized for each of
# the 3 files around it that doesn't have an own pawn one rank ahead of it.
# TODO: What about e.g. fianchetto? Or h3?
const PAWN_SHIELD_PENALTY = 20

@inline function knight_term(bb::UInt64, own_occ::UInt64, enemy_king_zone::UInt64)
    mobility = 0
    king_attackers = 0
    while bb != 0
        sq = trailing_zeros(bb)
        bb &= bb - 1
        atk = knight_attack_masks[sq+1]
        mobility += count_ones(atk & ~own_occ)
        if (atk & enemy_king_zone) != 0
            king_attackers += 1
        end
    end
    return mobility, king_attackers
end

@inline function slider_term(
    bb::UInt64,
    occ::UInt64,
    own_occ::UInt64,
    enemy_king_zone::UInt64,
    directions,
)
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

@inline function queen_term(
    bb::UInt64,
    occ::UInt64,
    own_occ::UInt64,
    enemy_king_zone::UInt64,
)
    mobility = 0
    king_attackers = 0
    while bb != 0
        sq = trailing_zeros(bb)
        bb &= bb - 1
        atk =
            sliding_attack_from_occupancy(sq, occ, ROOK_DIRECTIONS) |
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

    white_king_zone = king_attack_masks[king_square(board, WHITE)+1]
    black_king_zone = king_attack_masks[king_square(board, BLACK)+1]

    wn_mob, wn_katk =
        knight_term(board.bitboards[Piece.W_KNIGHT], white_occ, black_king_zone)
    bn_mob, bn_katk =
        knight_term(board.bitboards[Piece.B_KNIGHT], black_occ, white_king_zone)

    wb_mob, wb_katk = slider_term(
        board.bitboards[Piece.W_BISHOP],
        occ,
        white_occ,
        black_king_zone,
        BISHOP_DIRECTIONS,
    )
    bb_mob, bb_katk = slider_term(
        board.bitboards[Piece.B_BISHOP],
        occ,
        black_occ,
        white_king_zone,
        BISHOP_DIRECTIONS,
    )

    wr_mob, wr_katk = slider_term(
        board.bitboards[Piece.W_ROOK],
        occ,
        white_occ,
        black_king_zone,
        ROOK_DIRECTIONS,
    )
    br_mob, br_katk = slider_term(
        board.bitboards[Piece.B_ROOK],
        occ,
        black_occ,
        white_king_zone,
        ROOK_DIRECTIONS,
    )

    wq_mob, wq_katk =
        queen_term(board.bitboards[Piece.W_QUEEN], occ, white_occ, black_king_zone)
    bq_mob, bq_katk =
        queen_term(board.bitboards[Piece.B_QUEEN], occ, black_occ, white_king_zone)

    score =
        KNIGHT_MOBILITY_WEIGHT * (wn_mob - bn_mob) +
        BISHOP_MOBILITY_WEIGHT * (wb_mob - bb_mob) +
        ROOK_MOBILITY_WEIGHT * (wr_mob - br_mob) +
        QUEEN_MOBILITY_WEIGHT * (wq_mob - bq_mob)

    white_king_weight =
        bn_katk * KNIGHT_KING_ATTACK_WEIGHT +
        bb_katk * BISHOP_KING_ATTACK_WEIGHT +
        br_katk * ROOK_KING_ATTACK_WEIGHT +
        bq_katk * QUEEN_KING_ATTACK_WEIGHT
    black_king_weight =
        wn_katk * KNIGHT_KING_ATTACK_WEIGHT +
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
        for f = max(1, wf-1):min(8, wf+1)
            shield_sq = square_index(f, wr + 1)
            if !testbit(board.bitboards[Piece.W_PAWN], shield_sq)
                score -= PAWN_SHIELD_PENALTY
            end
        end
    end

    bk = king_square(board, BLACK)
    bf, br = file_rank(bk)
    if br >= 7
        for f = max(1, bf-1):min(8, bf+1)
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
stalemate, or draws, since generating legal moves to check for those on
every call would be too expensive to run at every quiescence node.
Checkmate/stalemate/draw detection is `_search`'s responsibility, since it
already generates legal moves for every node it visits regardless.
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
        game_phase_value += phase_weight(piece) * count_ones(bb)
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

# ---------------------------------------------------------------------------
# Static Exchange Evaluation (SEE)
# ---------------------------------------------------------------------------

# Unsigned per-piece-type centipawn values for SEE.
const SEE_VALUE = (100, 300, 300, 500, 900, 20_000, 100, 300, 300, 500, 900, 20_000)

@inline see_value(piece::Int) = piece == 0 ? 0 : SEE_VALUE[piece]

@inline function side_occupancy(board::Board, side::Side)::UInt64
    occ = zero(UInt64)
    for p in (side == WHITE ? WHITE_PIECES : BLACK_PIECES)
        occ |= board.bitboards[p]
    end
    return occ
end

"""
    attackers_to(board::Board, sq::Int, occ::UInt64) -> UInt64

Bitboard of every piece (either color) that attacks `sq`, given a custom
occupancy `occ` -- not necessarily `board`'s actual occupancy. Used by
`see` to simulate a shrinking board as pieces are captured off in an
exchange, without ever touching `board` itself. Pawn/knight/king attacks
are read straight from `board.bitboards` (their attack masks don't depend
on occupancy) and filtered against `occ` at the end; sliding attacks
already respect `occ` via `sliding_attack_from_occupancy`.
"""
function attackers_to(board::Board, sq::Int, occ::UInt64)::UInt64
    attackers = zero(UInt64)

    attackers |= pawn_attack_masks_white[sq+1] & board.bitboards[Piece.W_PAWN]
    attackers |= pawn_attack_masks_black[sq+1] & board.bitboards[Piece.B_PAWN]
    attackers |=
        knight_attack_masks[sq+1] &
        (board.bitboards[Piece.W_KNIGHT] | board.bitboards[Piece.B_KNIGHT])
    attackers |=
        king_attack_masks[sq+1] &
        (board.bitboards[Piece.W_KING] | board.bitboards[Piece.B_KING])

    diag = sliding_attack_from_occupancy(sq, occ, BISHOP_DIRECTIONS)
    attackers |=
        diag & (
            board.bitboards[Piece.W_BISHOP] | board.bitboards[Piece.B_BISHOP] |
            board.bitboards[Piece.W_QUEEN] | board.bitboards[Piece.B_QUEEN]
        )

    orth = sliding_attack_from_occupancy(sq, occ, ROOK_DIRECTIONS)
    attackers |=
        orth & (
            board.bitboards[Piece.W_ROOK] | board.bitboards[Piece.B_ROOK] |
            board.bitboards[Piece.W_QUEEN] | board.bitboards[Piece.B_QUEEN]
        )

    return attackers & occ
end

# Recursive half of SEE.
function see_exchange(
    board::Board,
    to::Int,
    side::Side,
    occ::UInt64,
    target_value::Int,
)::Int
    attackers = attackers_to(board, to, occ) & side_occupancy(board, side)
    if attackers == 0
        return 0
    end

    piece_range = side == WHITE ? (Piece.W_PAWN:Piece.W_KING) : (Piece.B_PAWN:Piece.B_KING)
    piece = 0
    sq = 0
    for p in piece_range
        bb = board.bitboards[p] & attackers
        if bb != 0
            piece = p
            sq = trailing_zeros(bb)
            break
        end
    end

    occ2 = clearbit(occ, sq)
    gain = target_value - see_exchange(board, to, opposite(side), occ2, see_value(piece))
    return max(0, gain)
end

"""
    see(board::Board, m::Move) -> Int

Static Exchange Evaluation for capture move `m`: play out the full capture
sequence on `m.to` (each side recaptures with its least valuable attacker,
alternating, only continuing if doing so doesn't lose material) using
bitboards only -- no `make_move!`/`undo_move!`. Returns the net material
result in centipawns for the side making `m` (positive = `m` wins
material). `m` is assumed to be an actual capture (`m.capture != 0` or
`m.en_passant`).

Simplifications:
- A promoting capture's attacker is valued at the pawn's own value, not
  the promoted piece.
- Pins are ignored.
"""
function see(board::Board, m::Move)::Int
    to = Int(m.to)
    from = Int(m.from)

    if m.en_passant
        captured_sq = square_index(file_rank(to)[1], file_rank(from)[2])
        captured_value = see_value(Piece.W_PAWN)
    else
        captured_sq = to
        captured_value = see_value(Int(m.capture))
    end

    occ = zero(UInt64)
    for p in ALL_PIECES
        occ |= board.bitboards[p]
    end
    occ = clearbit(occ, from)
    if m.en_passant
        occ = clearbit(occ, captured_sq)
    end

    attacker_value = see_value(piece_at(board, from))
    side = opposite(board.side_to_move)

    return captured_value - see_exchange(board, to, side, occ, attacker_value)
end
