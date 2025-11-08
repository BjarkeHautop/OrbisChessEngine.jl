using OrbisChessEngine
using Test

@testset "Pawn move generation" begin
    b = Board()

    # Generate white pawn moves from starting position
    white_moves = OrbisChessEngine.generate_pawn_moves(b)

    # There should be 16 moves: each of the 8 pawns can move 1 or 2 squares
    @test length(white_moves) == 16

    # Check a few specific moves
    expected_moves = [
        Move("a2", "a3"), Move("a2", "a4"), Move("e2", "e3"), Move("e2", "e4")
    ]

    for em in expected_moves
        @test em in white_moves
    end

    # Now test black pawn moves after switching side to move
    b.side_to_move = BLACK
    black_moves = OrbisChessEngine.generate_pawn_moves(b)

    # There should also be 16 moves for black pawns
    @test length(black_moves) == 16

    expected_black_moves = [
        Move(OrbisChessEngine.square_index(1, 7), OrbisChessEngine.square_index(1, 6)),  # a7 to a6
        Move(OrbisChessEngine.square_index(1, 7), OrbisChessEngine.square_index(1, 5)),  # a7 to a5
        Move(OrbisChessEngine.square_index(5, 7), OrbisChessEngine.square_index(5, 6)),  # e7 to e6
        Move(OrbisChessEngine.square_index(5, 7), OrbisChessEngine.square_index(5, 5))   # e7 to e5
    ]

    for em in expected_black_moves
        @test em in black_moves
    end

    # -----------------------------
    # Test en passant generation
    # -----------------------------
    # Example: white pawn on e5 can capture black pawn on d5 en passant
    b = Board()
    make_move!(b, Move("e2", "e4"))
    make_move!(b, Move("a7", "a5"))

    make_move!(b, Move("e4", "e5"))
    # Black plays d7-d5
    make_move!(b, Move("d7", "d5"))
    # Now white pawn on e5 can capture d5 en passant
    white_moves = OrbisChessEngine.generate_pawn_moves(b)
    en_passant_move = Move("e5", "d6"; capture = 7, en_passant = true)

    @test en_passant_move in white_moves

    make_move!(b, en_passant_move)
    # Check that the black pawn on d5 is removed
    @test !OrbisChessEngine.testbit(
        b.bitboards[Piece.B_PAWN], OrbisChessEngine.square_index(4, 5))
    # Check that white pawn is now on d6
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.W_PAWN], OrbisChessEngine.square_index(4, 6))

    # -----------------------------
    # Test promotion generation
    # -----------------------------

    b = Board(fen = "7r/6P1/2k5/8/8/8/8/4K3 w - - 0 1")
    promotion_moves = OrbisChessEngine.generate_pawn_moves(b)
    expected_promotions = [
        Move("g7", "g8"; promotion = Piece.W_QUEEN),
        Move("g7", "g8"; promotion = Piece.W_ROOK),
        Move("g7", "g8"; promotion = Piece.W_BISHOP),
        Move("g7", "g8"; promotion = Piece.W_KNIGHT),
        Move("g7", "h8"; promotion = Piece.W_QUEEN, capture = Piece.B_ROOK)
    ]
    for em in expected_promotions
        @test em in promotion_moves
    end
end

@testset "Pawn move no illegal across board captures" begin
    b = Board()
    make_move!(b, Move("a2", "a4"))
    make_move!(b, Move("h7", "h4"))

    pawn_moves = OrbisChessEngine.generate_pawn_moves(b)
    illegal_mv = Move("a4", "h4"; capture = Piece.B_PAWN)
    @test illegal_mv ∉ pawn_moves
end

@testset "generate_legal_moves for pawns" begin
    b = Board()
    make_move!(b, Move("e2", "e5"))
    make_move!(b, Move("d7", "d5"))

    legal_moves = generate_legal_moves(b)
    en_passant_move = Move("e5", "d6"; capture = Piece.B_PAWN, en_passant = true)
    @test en_passant_move in legal_moves
end

@testset "promotion captures black" begin
    b = Board(fen = "4k3/8/8/8/8/8/p7/1N2K3 b - - 0 1")
    pawn_moves = OrbisChessEngine.generate_pawn_moves(b)

    expected_pawn_moves = [
        Move(b, "a2a1=Q"),
        Move(b, "a2a1=R"),
        Move(b, "a2a1=B"),
        Move(b, "a2a1=N"),
        Move(b, "a2b1=Q"),
        Move(b, "a2b1=R"),
        Move(b, "a2b1=B"),
        Move(b, "a2b1=N")
    ]
    @test length(pawn_moves) == length(expected_pawn_moves)
    for em in expected_pawn_moves
        @test em in pawn_moves
    end
end

@testset "pawn mask" begin
    OrbisChessEngine.init_pawn_masks!()

    # Add explicit square tests ...
    @test true
end
