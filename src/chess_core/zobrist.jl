######################### Zobrist hashing #########################

# Use OffsetArrays and use 0 based indexing for easier mapping maybe?

using Random

# Tables
const ZOBRIST_PIECES = Array{UInt64}(undef, 12, 64)
const ZOBRIST_CASTLING = Array{UInt64}(undef, 16)
const ZOBRIST_EP = Array{UInt64}(undef, 8)
const ZOBRIST_SIDE = Ref{UInt64}(0)

function init_zobrist!()
    rng = MersenneTwister(1405)

    # Side to move
    ZOBRIST_SIDE[] = rand(rng, UInt64)

    # Pieces 12 × 64
    for p in 1:12, sq in 1:64

        ZOBRIST_PIECES[p, sq] = rand(rng, UInt64)
    end

    # Castling rights 0..15
    for i in 0:15
        ZOBRIST_CASTLING[i + 1] = rand(rng, UInt64)
    end

    # En passant files a..h
    for f in 1:8
        ZOBRIST_EP[f] = rand(rng, UInt64)
    end
end

# Initialize tables
init_zobrist!()

function zobrist_hash(board::Board)
    h::UInt64 = 0

    # Pieces
    for p in ALL_PIECES
        bb = board.bitboards[p]
        while bb != 0
            sq = trailing_zeros(bb) # 0..63
            h ⊻= ZOBRIST_PIECES[p, sq + 1]
            bb &= bb - 1
        end
    end

    # Side to move
    if board.side_to_move == BLACK
        h ⊻= ZOBRIST_SIDE[]
    end

    # Castling rights
    h ⊻= ZOBRIST_CASTLING[Int(board.castling_rights) + 1]

    # En passant (file only)
    if board.en_passant != -1
        file = (board.en_passant % 8) + 1
        h ⊻= ZOBRIST_EP[file]
    end

    return h
end
