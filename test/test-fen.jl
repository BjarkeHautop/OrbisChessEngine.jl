using OrbisChessEngine
using Test

@testset "FEN start positon" begin
    fen_string = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    board_fen = Board(fen = fen_string)
    board_start = Board()
    @test board_fen == board_start
end

@testset "FEN errors on invalid string" begin
    # Test 1: FEN with fewer than 8 ranks
    @test_throws AssertionError Board(
        fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP w KQkq - 0 1",
    )

    # Test 2: Rank with wrong number of squares
    @test_throws AssertionError Board(
        fen = "rnbqkbnr/pppppppp/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    )

    # Test 3: FEN with fewer than 4 fields
    @test_throws AssertionError Board(
        fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq",
    )

    # Test 4: Rank with too many squares (e.g., 9 squares)
    @test_throws AssertionError Board(
        fen = "rnbqkbnr/pppppppp/9/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    )
end

@testset "FEN en passant" begin
    fen_string = "rnbqkbnr/1pp1pppp/p7/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 1"
    board_fen = Board(fen = fen_string)
    b = Board()
    make_move!(b, Move("e2", "e4"))
    make_move!(b, Move("a7", "a6"))
    make_move!(b, Move("e4", "e5"))
    make_move!(b, Move("d7", "d5"))
    @test OrbisChessEngine.position_equal(board_fen, b)
end
