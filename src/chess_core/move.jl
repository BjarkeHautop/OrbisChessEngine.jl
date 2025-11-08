#########################
# Move representation   #
#########################

"""
    Move

A chess move.

- `from` is a square index (0-63)
- `to` is a square index (0-63)
- `promotion` is the piece type promoted to (0 if none)
- `capture` is captured piece type (0 if none)
- `castling`: 0 = normal, 1 = kingside, 2 = queenside
- `en_passant`: true if en passant capture
"""
struct Move
    from::Int8
    to::Int8
    promotion::Int8
    capture::Int8
    castling::Int8
    en_passant::Bool
end

# default constructor function
function Move(
        from, to; promotion = 0, capture = 0, castling = 0, en_passant = false)
    Move(from, to, promotion, capture, castling, en_passant)
end

file_char(file) = Char('a' + file - 1)
rank_char(rank) = string(rank)

square_name(sq) = string(file_char(sq % 8 + 1), rank_char(div(sq, 8) + 1))
# square_name(0) => "a1", square_name(63) => "h8"

function square_from_name(s::AbstractString)
    file = Int(lowercase(s[1])) - Int('a') + 1
    rank = parse(Int, s[2:end])
    return square_index(file, rank)
end

# Extra constructor from algebraic strings
function Move(
        from_str::AbstractString,
        to_str::AbstractString;
        capture = 0,
        promotion = 0,
        castling = 0,
        en_passant = false
)
    from = square_from_name(from_str)
    to = square_from_name(to_str)
    return Move(
        from,
        to;
        capture = capture,
        promotion = promotion,
        castling = castling,
        en_passant = en_passant
    )
end

# equality based on field values
function Base.:(==)(a::Move, b::Move)
    a.from == b.from &&
        a.to == b.to &&
        a.promotion == b.promotion &&
        a.capture == b.capture &&
        a.castling == b.castling &&
        a.en_passant == b.en_passant
end
