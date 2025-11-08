"""
Generic sliding mask generator.
- sq: square index (0..63)
- directions: list of (df, dr) directions
"""
function sliding_mask(sq, directions)
    mask = UInt64(0)
    f, r = file_rank(sq)
    for (df, dr) in directions
        nf, nr = f + df, r + dr
        while 1 < nf < 8 && 1 < nr < 8
            mask |= UInt64(1) << square_index(nf, nr)
            nf += df
            nr += dr
        end
    end
    return mask
end

"""
Generic sliding attack generator.
- sq: square index
- occ: occupancy bitboard
- directions: list of (df, dr) directions
"""
function sliding_attack_from_occupancy(sq, occ, directions)
    attacks = UInt64(0)
    f, r = file_rank(sq)

    for (df, dr) in directions
        nf, nr = f + df, r + dr
        while 1 <= nf <= 8 && 1 <= nr <= 8
            idx = square_index(nf, nr)
            attacks |= UInt64(1) << idx
            if testbit(occ, idx)
                break
            end
            nf += df
            nr += dr
        end
    end
    return attacks
end

"""
Generate all possible occupancy bitboards for the given mask
"""
function occupancy_variations(mask)
    bits = [i for i in 0:63 if testbit(mask, i)]   # actual square indices 0..63
    n = length(bits)
    variations = UInt64[]
    for i in 0:(2^n - 1)
        occ = UInt64(0)
        for j in 1:n
            if i & (1 << (j - 1)) != 0
                occ |= UInt64(1) << bits[j]
            end
        end
        push!(variations, occ)
    end
    return variations
end

"""
Count the number of bits set in a UInt64.
"""
count_bits(bb::UInt64) = count_ones(bb)

using Random

"""
Try to find a magic number for a given square.
- sq: square index 0–63
- masks: precomputed mask table (bishop or rook)
- attack_fn: function (sq, occ) → attacks
- tries: number of random candidates to attempt
"""
function find_magic(sq, masks, attack_fn; tries::Int = 10_000_000_000)
    mask = masks[sq + 1]
    n = count_ones(mask)
    shift = 64 - n

    # Generate all occupancies and their attacks
    occs = occupancy_variations(mask)
    attacks = [attack_fn(sq, occ) for occ in occs]

    for _ in 1:tries
        # Generate a random sparse number
        magic = rand(UInt64) & rand(UInt64) & rand(UInt64)

        # Skip bad magics (too few bits set in high region)
        if count_ones(magic & 0xFF00000000000000) < 6
            continue
        end

        used = Dict{Int, UInt64}()
        success = true

        for (occ, attack) in zip(occs, attacks)
            idx = Int(((occ * magic) & 0xFFFFFFFFFFFFFFFF) >> shift)
            if haskey(used, idx)
                if used[idx] != attack
                    success = false
                    break
                end
            else
                used[idx] = attack
            end
        end

        if success
            return magic
        end
    end
    println("Failed to find magic for square $sq after $tries tries")
    # Set it to a default value to avoid errors
    return UInt64(0)
end

"""
Compute magic numbers for all squares.
- masks: precomputed mask table (bishop or rook)
- attack_fn: function (sq, occ) → attacks
"""
function generate_magics(masks, attack_fn; tries::Int = 10_000_000_000)
    Random.seed!(1405)
    magics = Vector{UInt64}(undef, 64)
    for sq in 0:63
        magics[sq + 1] = find_magic(sq, masks, attack_fn; tries = tries)
    end
    return magics
end

# Bishop-specific
const BISHOP_DIRECTIONS = [(-1, -1), (-1, 1), (1, -1), (1, 1)]
bishop_mask(sq) = sliding_mask(sq, BISHOP_DIRECTIONS)

function bishop_attack_from_occupancy(sq, occ)
    sliding_attack_from_occupancy(sq, occ, BISHOP_DIRECTIONS)
end

BISHOP_MASKS = [bishop_mask(sq) for sq in 0:63]
BISHOP_ATTACKS = Vector{Vector{UInt64}}(undef, 64)

for sq in 0:63
    occs = occupancy_variations(BISHOP_MASKS[sq + 1])
    BISHOP_ATTACKS[sq + 1] = [bishop_attack_from_occupancy(sq, occ) for occ in occs]
end

# const BISHOP_MAGICS = generate_magics(BISHOP_MASKS, bishop_attack_from_occupancy)

# Build magic attack tables properly
BISHOP_ATTACK_TABLES = Vector{Vector{UInt64}}(undef, 64)

for sq in 0:63
    mask = BISHOP_MASKS[sq + 1]
    n = count_ones(mask)
    shift = 64 - n
    table_size = 1 << n

    table = zeros(UInt64, table_size)
    occs = occupancy_variations(mask)

    for occ in occs
        magic = BISHOP_MAGICS[sq + 1]
        idx = Int(((occ * magic) >> shift)) + 1
        attack = bishop_attack_from_occupancy(sq, occ)
        table[idx] = attack
    end

    BISHOP_ATTACK_TABLES[sq + 1] = table
end

function occupied_bb(board::Board)
    occ = UInt64(0)
    for bb in values(board.bitboards)
        occ |= bb
    end
    return occ
end

function generate_sliding_moves_magic!(
        board::Board,
        bb_piece::UInt64,
        mask_table::Vector{UInt64},
        attack_table::Vector{Vector{UInt64}},
        magic_table::Vector{UInt64},
        moves,
        start_idx::Int
)
    idx = start_idx

    # Determine friendly/enemy pieces
    if board.side_to_move == WHITE
        friendly_pieces = (Piece.W_PAWN):(Piece.W_KING)
        enemy_pieces = (Piece.B_PAWN):(Piece.B_KING)
    else
        friendly_pieces = (Piece.B_PAWN):(Piece.B_KING)
        enemy_pieces = (Piece.W_PAWN):(Piece.W_KING)
    end

    # Compute occupancy bitboards
    friendly_bb = zero(UInt64)
    for p in friendly_pieces
        friendly_bb |= board.bitboards[p]
    end
    full_occ = occupied_bb(board)

    @inbounds for sq in 0:63
        if !testbit(bb_piece, sq)
            continue
        end

        mask = mask_table[sq + 1]
        relevant_bits = count_bits(mask)
        shift = 64 - relevant_bits
        table = attack_table[sq + 1]

        idx_magic = Int((((full_occ & mask) * magic_table[sq + 1]) >> shift) + 1)
        @assert 1 <= idx_magic <= length(table)

        attacks = table[idx_magic] & ~friendly_bb

        while attacks != 0
            to_sq = trailing_zeros(attacks)

            capture = 0
            for p in enemy_pieces
                if testbit(board.bitboards[p], to_sq)
                    capture = p
                    break
                end
            end

            moves[idx] = Move(sq, to_sq; capture = capture)
            idx += 1

            attacks &= attacks - 1
        end
    end

    return idx  # new length after appending all generated moves
end

function generate_bishop_moves_magic!(
        board::Board,
        moves,
        start_idx::Int
)
    bb = board.side_to_move == WHITE ?
         board.bitboards[Piece.W_BISHOP] :
         board.bitboards[Piece.B_BISHOP]

    return generate_sliding_moves_magic!(
        board,
        bb,
        BISHOP_MASKS,
        BISHOP_ATTACK_TABLES,
        BISHOP_MAGICS,
        moves,
        start_idx
    )
end

function generate_bishop_moves_magic(
        board::Board
)::Vector{Move}
    moves = Vector{Move}(undef, 256)  # preallocate space for moves
    n_moves = generate_bishop_moves_magic!(board, moves, 1)
    return moves[1:(n_moves - 1)] # return only filled portion
end
