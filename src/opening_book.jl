# Polyglot uses
# 0: Black Pawn
# 1: White Pawn
# 2: Black Knight
# 3: White Knight
# 4: Black Bishop
# 5: White Bishop
# 6: Black Rook
# 7: White Rook
# 8: Black Queen
# 9: White Queen
# 10: Black King
# 11: White King

struct PolyglotEntry
    key::UInt64     # Polyglot hash
    move::UInt16    # encoded move
    weight::UInt16  # move frequency
    learn::UInt32   # unused
end

struct PolyglotBook
    entries::Vector{PolyglotEntry}
end

"""
    load_polyglot_book(path::String) -> PolyglotBook

Load a Polyglot opening book from the specified binary file. See for example
[free-opening-books](https://github.com/gmcheems-org/free-opening-books)
for several free Polyglot book files.
"""
function load_polyglot_book(path::String)
    bytes = read(path)
    n = div(length(bytes), 16)
    entries = Vector{PolyglotEntry}(undef, n)
    for i in 1:n
        offset = (i - 1) * 16 + 1
        key = ntoh(reinterpret(UInt64, bytes[offset:(offset + 7)])[1])
        move = ntoh(reinterpret(UInt16, bytes[(offset + 8):(offset + 9)])[1])
        weight = ntoh(reinterpret(UInt16, bytes[(offset + 10):(offset + 11)])[1])
        learn = ntoh(reinterpret(UInt32, bytes[(offset + 12):(offset + 15)])[1])
        entries[i] = PolyglotEntry(key, move, weight, learn)
    end
    return PolyglotBook(entries)
end

include("polyglot.jl")

# Castling flags (bits in board.castling_rights)
const WHITE_KING = 0x1  # K
const WHITE_QUEEN = 0x2  # Q
const BLACK_KING = 0x4  # k
const BLACK_QUEEN = 0x8  # q

# Map board piece constants to Polyglot piece indices (0..11)
const POLYGLOT_PIECE_INDEX = Dict(
    Piece.B_PAWN => 0, Piece.W_PAWN => 1, Piece.B_KNIGHT => 2, Piece.W_KNIGHT => 3,
    Piece.B_BISHOP => 4, Piece.W_BISHOP => 5,
    Piece.B_ROOK => 6, Piece.W_ROOK => 7, Piece.B_QUEEN => 8, Piece.W_QUEEN => 9,
    Piece.B_KING => 10, Piece.W_KING => 11
)

# Map castling flag to 0..3 index for Polyglot
function flag_index(flag::UInt8)
    return flag == WHITE_KING ? 0 :
           flag == WHITE_QUEEN ? 1 :
           flag == BLACK_KING ? 2 :
           flag == BLACK_QUEEN ? 3 :
           error("invalid castling flag")
end

function polyglot_piece_index(piece, square)
    idx = POLYGLOT_PIECE_INDEX[piece]   # 0..11
    return idx * 64 + square            # 0..767
end

file_of(square) = square % 8

function has_pawn_for_en_passant(board::Board, file::Int)::Bool
    if board.side_to_move == WHITE
        # White pawns on rank 5 (row 4)
        rank = 4
        side_pawn = Piece.W_PAWN
    else
        # Black pawns on rank 4 (row 3)
        rank = 3
        side_pawn = Piece.B_PAWN
    end

    for df in (-1, 1)
        f = file + df
        if 0 <= f <= 7
            sq = rank * 8 + f
            if testbit(board.bitboards[side_pawn], sq)
                return true
            end
        end
    end

    return false
end

function polyglot_hash(board::Board)::UInt64
    h = UInt64(0)

    # 1. Pieces on squares
    for sq in 0:63
        piece = piece_at(board, sq)    # returns 0..12
        if piece != 0
            index = polyglot_piece_index(piece, sq)
            h ⊻= POLYGLOT_RANDOM_ARRAY[index + 1]
        end
    end

    # 2. Castling rights
    for flag in [WHITE_KING, WHITE_QUEEN, BLACK_KING, BLACK_QUEEN]
        if board.castling_rights & flag != 0
            idx = 768 + flag_index(flag)
            h ⊻= POLYGLOT_RANDOM_ARRAY[idx + 1]
        end
    end

    # 3. En passant
    if board.en_passant != -1
        file = file_of(board.en_passant)
        if has_pawn_for_en_passant(board, file)
            idx = 772 + file
            h ⊻= POLYGLOT_RANDOM_ARRAY[idx + 1]
        end
    end

    # 4. Side to move
    if board.side_to_move == WHITE
        h ⊻= POLYGLOT_RANDOM_ARRAY[781]   # entry 780 +1 for Julia
    end

    return h
end

using Distributions

function book_move(board::Board, book::PolyglotBook)
    # Add seed?

    key = polyglot_hash(board)
    total_weight = 0
    count = 0
    # First pass: sum weights of matching entries
    for e in book.entries
        if e.key == key
            total_weight += e.weight
            count += 1
        end
    end
    if count == 0
        return nothing
    end

    # Sample without allocating arrays
    target = rand() * total_weight
    acc = 0
    for e in book.entries
        if e.key == key
            acc += e.weight
            if acc >= target
                return decode_polyglot_move(e.move, board)
            end
        end
    end
end

function decode_polyglot_move(code::UInt16, board::Board)
    from = Int((code >> 6) & 0x3f)
    to = Int(code & 0x3f)
    prom = Int((code >> 12) & 0x7)

    # Promotion piece mapping
    if prom == 0
        promotion = 0
    else
        if board.side_to_move == WHITE
            promotion = (prom == 1 ? Piece.W_KNIGHT :
                         prom == 2 ? Piece.W_BISHOP :
                         prom == 3 ? Piece.W_ROOK :
                         Piece.W_QUEEN)
        else
            promotion = (prom == 1 ? Piece.B_KNIGHT :
                         prom == 2 ? Piece.B_BISHOP :
                         prom == 3 ? Piece.B_ROOK :
                         Piece.B_QUEEN)
        end
    end

    # Capture
    capture = piece_at(board, to)

    # en passant detection
    enp = false
    if piece_at(board, from) in (Piece.W_PAWN, Piece.B_PAWN) &&
       to == board.en_passant
        enp = true
        capture = board.side_to_move == WHITE ? Piece.B_PAWN : Piece.W_PAWN
    end

    # Castling (Polyglot encodes as king→rook square)
    if piece_at(board, from) in (Piece.W_KING, Piece.B_KING)
        if board.side_to_move == WHITE
            if from == 4 && to == 7   # e1 -> h1
                return Move(4, 6; castling = 1)  # kingside
            elseif from == 4 && to == 0 # e1 -> a1
                return Move(4, 2; castling = 2)  # queenside
            end
        else
            if from == 60 && to == 63  # e8 -> h8
                return Move(60, 62; castling = 1) # kingside
            elseif from == 60 && to == 56 # e8 -> a8
                return Move(60, 58; castling = 2) # queenside
            end
        end
    end

    return Move(from, to;
        promotion = promotion,
        capture = capture,
        castling = 0,
        en_passant = enp)
end

const KOMODO_OPENING_BOOK = load_polyglot_book(joinpath(
    @__DIR__, "..", "assets", "komodo.bin"))
