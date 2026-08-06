using OrbisChessEngine
using Test

@testset "find_magic_number tests" begin
    res = redirect_stdout(devnull) do
        OrbisChessEngine.generate_magics(
            OrbisChessEngine.BISHOP_MASKS,
            OrbisChessEngine.bishop_attack_from_occupancy;
            tries = 1_000_000,
        )
    end

    @test !all(x -> x == 0, res)
end

@testset "generate_bishop_moves_magic tests" begin
    b = Board()
    moves_magic = OrbisChessEngine.generate_bishop_moves_magic(b)
    moves_standard = OrbisChessEngine.generate_bishop_moves(b)

    @test length(moves_magic) == length(moves_standard)

    move_set_magic = Set(moves_magic)
    move_set_standard = Set(moves_standard)
    @test move_set_magic == move_set_standard

    b = Board(fen = "4k3/pppppppp/8/8/4B3/6B1/PPPPPPPP/4K3 w - - 0 1")
    moves_magic = OrbisChessEngine.generate_bishop_moves_magic(b)
    moves_standard = OrbisChessEngine.generate_bishop_moves(b)

    @test length(moves_magic) == length(moves_standard)

    # Check that all moves are the same
    move_set_magic = Set(moves_magic)
    move_set_standard = Set(moves_standard)
    @test move_set_magic == move_set_standard
end

@testset "bishop_mask" begin
    BISHOP_MASKS = [OrbisChessEngine.bishop_mask(sq) for sq = 0:63]
    @test BISHOP_MASKS[1] == 0x0040201008040200
    @test BISHOP_MASKS[36] == 0x0022140014224000
end
