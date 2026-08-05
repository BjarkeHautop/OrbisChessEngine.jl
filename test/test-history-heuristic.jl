using OrbisChessEngine
using Test

@testset "update_history! only tracks quiet moves" begin
    OrbisChessEngine.HISTORY .= 0

    quiet = Move("g1", "f3")
    capture = Move("e4", "d5"; capture = Piece.B_PAWN)

    OrbisChessEngine.update_history!(WHITE, quiet, 4)
    @test OrbisChessEngine.HISTORY[1, quiet.from + 1, quiet.to + 1] == 16  # depth^2

    OrbisChessEngine.update_history!(WHITE, capture, 4)
    @test OrbisChessEngine.HISTORY[1, capture.from + 1, capture.to + 1] == 0
end

@testset "update_history! accumulates and clamps at HISTORY_MAX" begin
    OrbisChessEngine.HISTORY .= 0

    m = Move("b1", "c3")
    OrbisChessEngine.update_history!(BLACK, m, 10)  # +100
    @test OrbisChessEngine.HISTORY[2, m.from + 1, m.to + 1] == 100

    OrbisChessEngine.update_history!(BLACK, m, 10)  # +100 again
    @test OrbisChessEngine.HISTORY[2, m.from + 1, m.to + 1] == 200

    # Large enough to hit the clamp
    OrbisChessEngine.update_history!(BLACK, m, 1000)
    @test OrbisChessEngine.HISTORY[2, m.from + 1, m.to + 1] == OrbisChessEngine.HISTORY_MAX

    # White's table for the same (from, to) is untouched
    @test OrbisChessEngine.HISTORY[1, m.from + 1, m.to + 1] == 0
end

@testset "move_ordering_score orders quiet moves by history, below killers" begin
    OrbisChessEngine.HISTORY .= 0
    fill!(OrbisChessEngine.KILLERS[1], OrbisChessEngine.NO_MOVE)

    b = Board()
    quiet_hi = Move("g1", "f3")   # White knight development, no check
    quiet_lo = Move("b1", "c3")

    OrbisChessEngine.update_history!(WHITE, quiet_hi, 6)  # +36

    score_hi = OrbisChessEngine.move_ordering_score(b, quiet_hi, 0)
    score_lo = OrbisChessEngine.move_ordering_score(b, quiet_lo, 0)
    @test score_hi > score_lo
    @test score_hi == 36

    # A killer move at this ply must still outrank a history-scored quiet move
    OrbisChessEngine.store_killer!(quiet_lo, 0)
    score_killer = OrbisChessEngine.move_ordering_score(b, quiet_lo, 0)
    @test score_killer > score_hi
    @test score_killer == 4000

    fill!(OrbisChessEngine.KILLERS[1], OrbisChessEngine.NO_MOVE)  # reset for other tests
end
