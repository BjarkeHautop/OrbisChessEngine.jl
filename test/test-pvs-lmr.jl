using OrbisChessEngine
using Test

@testset "PVS+LMR still finds Scholar Mate" begin
    b = Board()
    moves = [Move("f2", "f3"), Move("e7", "e5"), Move("g2", "g4")]
    for m in moves
        make_move!(b, m)
    end
    result = search(b; depth = 3, opening_book = nothing)
    @test result.score < -10_000  # Checkmate
    @test result.move == Move("d8", "h4")
end

@testset "PVS+LMR does not hang a piece at a depth deep enough to trigger LMR" begin
    # Same position as the truncated-iteration regression test in
    # test-search.jl, but searched to a fixed depth (no time budget) deep
    # enough that LMR reductions definitely kick in (LMR_MIN_DEPTH = 3,
    # LMR_FULL_DEPTH_MOVES = 3), to check reductions don't prune away the
    # move that keeps White's knight on d4 safe.
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

@testset "PVS+LMR search completes on a middlegame position with many quiet moves" begin
    # A position with plenty of legal (mostly quiet) moves, so the move
    # loop at each node is long enough to reach LMR_FULL_DEPTH_MOVES and
    # exercise reduced-depth scouts, verification re-searches, and
    # full-window re-searches.
    b = Board(fen = "rnbq1rk1/pp4bp/2pp1np1/3Ppp2/2P5/2N2NP1/PP2PPBP/R1BQ1RK1 w - e6 0 1")
    result = search(b; depth = 5, opening_book = nothing)
    @test result !== nothing

    legal = OrbisChessEngine.generate_legal_moves(b)
    @test result.move in legal
end
