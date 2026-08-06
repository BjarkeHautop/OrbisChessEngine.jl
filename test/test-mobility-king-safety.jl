using OrbisChessEngine
using Test

@testset "knight_term computes mobility and king-zone attacks" begin
    e5 = OrbisChessEngine.square_index("e5")
    knight_bb = UInt64(1) << e5

    # Knight on e5, otherwise-empty board: all 8 target squares are free.
    mobility, king_attackers = OrbisChessEngine.knight_term(knight_bb, UInt64(0), UInt64(0))
    @test mobility == 8
    @test king_attackers == 0

    # Occupying all 8 target squares with "own" pieces removes all mobility.
    own_occ = OrbisChessEngine.knight_attack_masks[e5 + 1]
    mobility2, _ = OrbisChessEngine.knight_term(knight_bb, own_occ, UInt64(0))
    @test mobility2 == 0

    # An "enemy king zone" equal to the knight's own attack set is detected
    # as one attacker.
    _, king_attackers2 = OrbisChessEngine.knight_term(
        knight_bb, UInt64(0), OrbisChessEngine.knight_attack_masks[e5 + 1])
    @test king_attackers2 == 1
end

@testset "mobility term rewards a centralized piece over a cornered one" begin
    # Same knight, same kings (far from the knight, so no king-safety
    # contribution), just centralized vs cornered — isolates mobility.
    center = Board(fen = "8/8/8/4N3/8/8/8/K6k w - - 0 1")
    corner = Board(fen = "N7/8/8/8/8/8/8/K6k w - - 0 1")
    @test OrbisChessEngine.mobility_and_king_safety(center) >
          OrbisChessEngine.mobility_and_king_safety(corner)
end

@testset "pawn_shield_score penalizes a missing shield" begin
    # Black king on e5 (not on its own back two ranks) so only White's
    # shield status varies between the two positions being compared.
    intact = Board(fen = "8/8/8/4k3/8/8/5PPP/6K1 w - - 0 1")
    missing = Board(fen = "8/8/8/4k3/8/8/8/6K1 w - - 0 1")
    @test OrbisChessEngine.pawn_shield_score(intact) == 0
    @test OrbisChessEngine.pawn_shield_score(missing) ==
          -3 * OrbisChessEngine.PAWN_SHIELD_PENALTY
    @test OrbisChessEngine.pawn_shield_score(intact) >
          OrbisChessEngine.pawn_shield_score(missing)
end

@testset "evaluate stays symmetric for the starting position" begin
    @test evaluate(Board()) == 0
end
