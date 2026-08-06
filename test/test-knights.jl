using OrbisChessEngine
using Test

@testset "Knight move generation" begin
    b = Board()

    # White knights at b1 and g1
    white_knight_moves = OrbisChessEngine.generate_knight_moves(b)

    # Each knight has 2 moves at the starting position, so total 4 moves
    @test length(white_knight_moves) == 4

    expected_moves =
        [Move("b1", "a3"), Move("b1", "c3"), Move("g1", "f3"), Move("g1", "h3")]

    for em in expected_moves
        @test em in white_knight_moves
    end
    make_move!(b, Move("b1", "c3"))

    black_knight_moves = OrbisChessEngine.generate_knight_moves(b)
    @test length(black_knight_moves) == 4

    make_move!(b, Move("g8", "f6"))
    make_move!(b, Move("c3", "d5"))
    black_knight_moves = OrbisChessEngine.generate_knight_moves(b)
    @test length(black_knight_moves) == 7

    capture_move = Move("f6", "d5"; capture = Piece.W_KNIGHT)
    @test capture_move in black_knight_moves
end

@testset "Knight move generation in place" begin
    b = Board()
    moves = Vector{Move}(undef, 256)  # preallocate a large enough buffer
    start_idx = 1
    idx = OrbisChessEngine.generate_knight_moves!(b, moves, start_idx)
    idx -= 1  # Adjust for 1-based indexing
    # Each knight has 2 moves at the starting position, so total 4 moves
    @test idx == 4

    expected_moves =
        [Move("b1", "a3"), Move("b1", "c3"), Move("g1", "f3"), Move("g1", "h3")]

    for em in expected_moves
        @test em in moves
    end

    make_move!(b, Move("b1", "c3"))
    idx = OrbisChessEngine.generate_knight_moves!(b, moves, start_idx)
    idx -= 1  # Adjust for 1-based indexing
    @test idx == 4

    make_move!(b, Move("g8", "f6"))
    make_move!(b, Move("c3", "d5"))
    idx = OrbisChessEngine.generate_knight_moves!(b, moves, start_idx)
    idx -= 1  # Adjust for 1-based indexing
    @test idx == 7
end

@testset "Knight attack masks" begin
    OrbisChessEngine.init_knight_masks!()

    # a1; Neighbors: c2 and b3
    @test OrbisChessEngine.knight_attack_masks[1] == 0x20400

    # h1; Neighbors: f2 and g3
    @test OrbisChessEngine.knight_attack_masks[8] == 0x402000

    # a8; Neighbors: b6 and c7
    @test OrbisChessEngine.knight_attack_masks[57] == 0x0004020000000000

    # h8; Neighbors: f7 and g6
    @test OrbisChessEngine.knight_attack_masks[64] == 0x0020400000000000

    # d4; Neighbors: c2, b3, b5, c6, e2, f3, f5, e6
    @test OrbisChessEngine.knight_attack_masks[28] == 0x0000142200221400
end
