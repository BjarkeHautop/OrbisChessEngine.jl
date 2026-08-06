using OrbisChessEngine
using Test

@testset "Bishop move generation" begin
    b = Board()

    # White bishops at c1 and f1, blocked by pawns → no moves
    white_bishop_moves = OrbisChessEngine.generate_bishop_moves(b)
    @test length(white_bishop_moves) == 0

    # Unblock c1 bishop by moving pawn d2 → d3
    b.bitboards[Piece.W_PAWN] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_PAWN],
        OrbisChessEngine.square_index(4, 2),
    )
    b.bitboards[Piece.W_PAWN] = OrbisChessEngine.setbit(
        b.bitboards[Piece.W_PAWN],
        OrbisChessEngine.square_index(4, 3),
    )

    white_bishop_moves = OrbisChessEngine.generate_bishop_moves(b)
    expected_moves = [
        Move("c1", "d2"),
        Move("c1", "e3"),
        Move("c1", "f4"),
        Move("c1", "g5"),
        Move("c1", "h6"),
    ]

    for em in expected_moves
        @test em in white_bishop_moves
    end
end

@testset "Rook move generation" begin
    b = Board()

    # Unblock a1 rook by moving pawn a2 → a4
    b.bitboards[Piece.W_PAWN] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_PAWN],
        OrbisChessEngine.square_index(1, 2),
    )
    b.bitboards[Piece.W_PAWN] = OrbisChessEngine.setbit(
        b.bitboards[Piece.W_PAWN],
        OrbisChessEngine.square_index(1, 4),
    )

    white_rook_moves = OrbisChessEngine.generate_rook_moves(b)

    expected_moves = [
        Move(OrbisChessEngine.square_index(1, 1), OrbisChessEngine.square_index(1, 2)),  # a1 → a2
        Move(OrbisChessEngine.square_index(1, 1), OrbisChessEngine.square_index(1, 3)),  # a1 → a3
    ]

    for em in expected_moves
        @test em in white_rook_moves
    end
end

@testset "Rook move disables castling" begin
    b = Board()

    # Clear pieces between king and rook for white kingside castling
    b.bitboards[Piece.W_KNIGHT] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_KNIGHT],
        OrbisChessEngine.square_index(2, 1),
    )
    b.bitboards[Piece.W_BISHOP] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_BISHOP],
        OrbisChessEngine.square_index(3, 1),
    )
    b.bitboards[Piece.W_QUEEN] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_QUEEN],
        OrbisChessEngine.square_index(4, 1),
    )
    b.bitboards[Piece.W_BISHOP] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_BISHOP],
        OrbisChessEngine.square_index(6, 1),
    )
    b.bitboards[Piece.W_KNIGHT] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_KNIGHT],
        OrbisChessEngine.square_index(7, 1),
    )

    # Clear all white pawns
    b.bitboards[Piece.W_PAWN] = UInt64(0)
    # Add black pawn on a2 and h2
    b.bitboards[Piece.B_PAWN] = OrbisChessEngine.setbit(
        b.bitboards[Piece.B_PAWN],
        OrbisChessEngine.square_index(1, 2),
    )
    b.bitboards[Piece.B_PAWN] = OrbisChessEngine.setbit(
        b.bitboards[Piece.B_PAWN],
        OrbisChessEngine.square_index(8, 2),
    )

    # Step 1: move rook to f1
    m1 = Move("h1", "f1")
    make_move!(b, m1)

    b.side_to_move = WHITE

    # Step 2: move rook back to h1
    m2 = Move("f1", "h1")
    make_move!(b, m2)

    b.side_to_move = WHITE

    # Generate legal moves for white
    legal_moves = generate_legal_moves(b)

    # e1 → g1 (short castle) should no longer be allowed
    castling_move = Move("e1", "g1"; castling = 1)
    @test !(castling_move in legal_moves)

    # King should still be able to move normally
    @test Move("e1", "f1") in legal_moves

    # Long castling should still be allowed
    long_castle = Move("e1", "c1"; castling = 2)
    @test long_castle in legal_moves
end

@testset "Queen move generation" begin
    b = Board()

    # Unblock d1 queen by moving pawn d2 → d4 and e2 → e4
    b.bitboards[Piece.W_PAWN] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_PAWN],
        OrbisChessEngine.square_index(4, 2),
    )
    b.bitboards[Piece.W_PAWN] = OrbisChessEngine.setbit(
        b.bitboards[Piece.W_PAWN],
        OrbisChessEngine.square_index(4, 4),
    )
    b.bitboards[Piece.W_PAWN] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_PAWN],
        OrbisChessEngine.square_index(5, 2),
    )
    b.bitboards[Piece.W_PAWN] = OrbisChessEngine.setbit(
        b.bitboards[Piece.W_PAWN],
        OrbisChessEngine.square_index(5, 4),
    )

    white_queen_moves = OrbisChessEngine.generate_queen_moves(b)

    expected_moves = [
        Move(OrbisChessEngine.square_index(4, 1), OrbisChessEngine.square_index(4, 2)),  # d1 → d2
        Move(OrbisChessEngine.square_index(4, 1), OrbisChessEngine.square_index(4, 3)),  # d1 → d3
        Move(OrbisChessEngine.square_index(4, 1), OrbisChessEngine.square_index(5, 2)),  # d1 → e2
        Move(OrbisChessEngine.square_index(4, 1), OrbisChessEngine.square_index(6, 3)),  # d1 → f3
        Move(OrbisChessEngine.square_index(4, 1), OrbisChessEngine.square_index(7, 4)),  # d1 → g4
        Move(OrbisChessEngine.square_index(4, 1), OrbisChessEngine.square_index(8, 5)),  # d1 → h5
    ]

    for em in expected_moves
        @test em in white_queen_moves
    end
end
