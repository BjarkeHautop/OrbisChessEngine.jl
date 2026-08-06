using OrbisChessEngine
using Test

@testset "Evaluation" begin
    # Starting position should be balanced
    b = Board()
    @test evaluate(b) == 0

    m1 = Move("e2", "e4")
    make_move!(b, m1)
    M2 = Move("d7", "d5")
    make_move!(b, M2)

    # No longer exactly 0: 1.e4 also opens White's queen's diagonal at e2,
    # while 1...d5 leaves Black's queen's diagonal blocked at e7, so the
    # mobility term now has a small, legitimate opinion here.
    @test abs(evaluate(b)) < 10

    M3 = Move("e4", "d5"; capture = Piece.B_PAWN)
    make_move!(b, M3)
    @test evaluate(b) > 100

    M4 = Move("d8", "d5"; capture = Piece.W_PAWN)
    make_move!(b, M4)
    @test evaluate(b) < 100
end
