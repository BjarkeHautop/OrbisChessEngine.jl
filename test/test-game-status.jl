using OrbisChessEngine
using Test

@testset "Game over detection" begin
    b = Board()

    @test game_status(b) == :ongoing

    # Fool's mate position (black wins)
    moves = [
        Move(OrbisChessEngine.square_index(6, 2), OrbisChessEngine.square_index(6, 3)),  # f2 to f3
        Move(OrbisChessEngine.square_index(5, 7), OrbisChessEngine.square_index(5, 5)),  # e7 to e5
        Move(OrbisChessEngine.square_index(7, 2), OrbisChessEngine.square_index(7, 4)),  # g2 to g4
        Move(OrbisChessEngine.square_index(4, 8), OrbisChessEngine.square_index(8, 4)),  # d8 to h4 (checkmate)
    ]

    for m in moves
        make_move!(b, m)
    end

    # Check game over status
    @test game_status(b) == :checkmate_black  # white is checkmated
    b.side_to_move = BLACK  # switch to black
    @test game_status(b) == :ongoing  # black is not checkmated

    # -----------------------------
    # Stalemate example: king vs king + pawn
    # -----------------------------
    b = Board(fen = "1k6/1P6/1K6/8/8/8/8/8 b - - 0 1")
    @test game_status(b) == :stalemate
    b.side_to_move = WHITE
    @test game_status(b) == :ongoing

    # -----------------------------
    # Threefold repetition example
    # -----------------------------
    # Shuffle knights back and forth from starting position
    b = Board()
    moves = [
        Move(OrbisChessEngine.square_index(2, 1), OrbisChessEngine.square_index(3, 3)),  # b1 to c3
        Move(OrbisChessEngine.square_index(7, 8), OrbisChessEngine.square_index(6, 6)),  # g8 to f6
        Move(OrbisChessEngine.square_index(3, 3), OrbisChessEngine.square_index(2, 1)),  # c3 to b1
        Move(OrbisChessEngine.square_index(6, 6), OrbisChessEngine.square_index(7, 8)),  # f6 to g8
    ]
    for i = 1:3
        for m in moves
            make_move!(b, m)
        end
    end
    @test game_status(b) == :draw_threefold
    # Lose a move intentionally so it's the other side to move
    make_move!(b, Move(b, "g1f3"))
    make_move!(b, Move(b, "g8f6"))
    make_move!(b, Move(b, "f3h4"))
    make_move!(b, Move(b, "f6g8"))
    make_move!(b, Move(b, "h4g1"))
    @test game_status(b) == :ongoing

    # -----------------------------
    # Fifty-move rule example
    # -----------------------------
    b = Board()
    b.halfmove_clock = 98  # Set to 98 halfmoves (49 full moves)
    @test game_status(b) == :ongoing
    b.side_to_move = BLACK
    @test game_status(b) == :ongoing

    b.side_to_move = WHITE

    # Now make the 99th and 100th halfmove
    moves = [Move(b, "g1f3"), Move(b, "g8f6")]
    for m in moves
        make_move!(b, m)
    end
    @test game_status(b) == :draw_fiftymove
    b.side_to_move = BLACK
    @test game_status(b) == :draw_fiftymove
end

@testset "Insufficent material" begin
    b = Board(fen = "4k3/8/8/8/8/8/8/4K3 w - - 0 1")  # King vs King
    @test game_status(b) == :draw_insufficient_material

    b = Board(fen = "4k3/8/2b5/8/8/8/2B5/4K3 w - - 0 1") # King and Bishop vs King and Bishop (same color)
    @test game_status(b) == :draw_insufficient_material

    b = Board(fen = "4k3/8/8/8/8/2N5/8/4K3 w - - 0 1") # King and Knight vs King
    @test game_status(b) == :draw_insufficient_material
end

@testset "Not insufficent material" begin
    b = Board(fen = "5k2/8/4K3/4B3/4N3/8/8/8 b - - 0 1") # King, Bishop, Knight vs King
    @test OrbisChessEngine.is_insufficient_material(b) == false

    g = Game()
    @test game_status(g) == :ongoing
end

@testset "Game status time out" begin
    g = Game()
    g.white_time = 0  # Simulate white running out of time
    @test game_status(g) == :timeout_white

    g = Game()
    g.black_time = 0  # Simulate black running out of time
    @test game_status(g) == :timeout_black
end
