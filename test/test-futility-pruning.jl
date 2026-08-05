using OrbisChessEngine
using Test

@testset "Futility/RFP still finds Scholar Mate" begin
    b = Board()
    moves = [Move("f2", "f3"), Move("e7", "e5"), Move("g2", "g4")]
    for m in moves
        make_move!(b, m)
    end
    result = search(b; depth = 3, opening_book = nothing)
    @test result.score < -10_000  # Checkmate
    @test result.move == Move("d8", "h4")
end

@testset "Futility/RFP does not hang a piece at depths that trigger both" begin
    # Same regression position as the truncated-iteration and PVS+LMR
    # regression tests: White's knight on d4 is undefended and attacked by
    # the bishop on c5. Searched at a fixed depth (no time budget) that's
    # comfortably within RFP_MAX_DEPTH (6) and FUTILITY_MAX_DEPTH (3) for
    # the deeper nodes near the leaves, to check the new prunings don't
    # prune away the move that keeps the knight safe.
    b = Board(fen = "r1bqk2r/1p1n1ppp/p4n2/2bP4/3N1P2/8/PP1NB1PP/R1BQK2R w KQkq - 1 11")
    result = search(b; depth = 6, opening_book = nothing)
    @test result !== nothing

    make_move!(b, result.move)
    d4 = OrbisChessEngine.square_from_name("d4")
    if OrbisChessEngine.piece_at(b, d4) == Piece.W_KNIGHT
        @test OrbisChessEngine.square_attacked(b, d4, WHITE) ||
              !OrbisChessEngine.square_attacked(b, d4, BLACK)
    end
end

@testset "Futility/RFP does not misfire in check or in the endgame" begin
    # A position where the side to move is in check (but not checkmate):
    # RFP/futility must not prune here (own_in_check guards both), so the
    # engine must still find one of the legal escapes.
    b = Board(fen = "4k3/8/8/8/8/8/4r3/4K3 w - - 0 1")
    result = search(b; depth = 3, opening_book = nothing)
    @test result !== nothing
    legal = OrbisChessEngine.generate_legal_moves(b)
    @test result.move in legal

    # A simple king-and-pawn endgame: RFP/futility are disabled here
    # (board_is_endgame guard), so this is mostly a smoke test that a
    # low-material position still searches without error.
    endgame = Board(fen = "8/8/4k3/8/4K3/8/4P3/8 w - - 0 1")
    result2 = search(endgame; depth = 6, opening_book = nothing)
    @test result2 !== nothing
end

@testset "Futility/RFP search completes and stays legal on a middlegame position" begin
    b = Board(fen = "rnbq1rk1/pp4bp/2pp1np1/3Ppp2/2P5/2N2NP1/PP2PPBP/R1BQ1RK1 w - e6 0 1")
    result = search(b; depth = 7, opening_book = nothing)
    @test result !== nothing

    legal = OrbisChessEngine.generate_legal_moves(b)
    @test result.move in legal
end
