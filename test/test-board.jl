using OrbisChessEngine
using Test

@testset "Board basics" begin
    b = Board()

    # side to move should be white
    @test b.side_to_move == WHITE

    # castling rights should be 0xF at start (all available)
    @test b.castling_rights == 0xF

    # en passant should be unset (-1)
    @test b.en_passant == -1

    # white pawns bitboard should match second rank
    expected_white_pawns = 0x000000000000FF00
    @test b.bitboards[Piece.W_PAWN] == expected_white_pawns

    # black rooks on a8 and h8
    expected_black_rooks = 0x8100000000000000
    @test b.bitboards[Piece.B_ROOK] == expected_black_rooks

    # Move e2 to e4
    m_square_index = Move(
        OrbisChessEngine.square_index(5, 2), OrbisChessEngine.square_index(5, 4))
    m_chess_notation = Move("e2", "e4")
    @test m_square_index == m_chess_notation
end

@testset "Square indexing" begin
    # a1 → 0
    @test OrbisChessEngine.square_index(1, 1) == 0

    # h1 → 7
    @test OrbisChessEngine.square_index(8, 1) == 7

    # a8 → 56
    @test OrbisChessEngine.square_index(1, 8) == 56

    # h8 → 63
    @test OrbisChessEngine.square_index(8, 8) == 63
end

@testset "Bit operations" begin
    sq = OrbisChessEngine.square_index(5, 2)  # e2
    bb = UInt64(0)

    # set bit
    bb = OrbisChessEngine.setbit(bb, sq)
    @test OrbisChessEngine.testbit(bb, sq)

    # clear bit
    bb = OrbisChessEngine.clearbit(bb, sq)
    @test !OrbisChessEngine.testbit(bb, sq)
end

@testset "Phase value calculated correctly" begin
    b = Board()
    @test b.game_phase_value == 24
    @test b.eval_score == 0

    make_move!(b, Move("e2", "e3"))
    make_move!(b, Move("d7", "d5"))
    make_move!(b, Move("f1", "c4"))
    make_move!(b, Move("d5", "c4"; capture = Piece.W_BISHOP))

    @test b.game_phase_value == 23
    @test b.eval_score < 0

    eval_score, game_phase_value = OrbisChessEngine.compute_eval_and_phase(b)
    @test game_phase_value == b.game_phase_value
    @test eval_score == b.eval_score

    make_move!(b, Move("d1", "c4"; capture = Piece.B_PAWN))
    undo_move!(b, Move("d1", "c4"; capture = Piece.B_PAWN))
    @test game_phase_value == b.game_phase_value
    @test eval_score == b.eval_score
end

@testset "init_zobrist!" begin
    OrbisChessEngine.init_zobrist!()

    # Check that side is a UInt64
    @test isa(OrbisChessEngine.ZOBRIST_SIDE[], UInt64)

    # Check pieces array dimensions and type
    @test size(OrbisChessEngine.ZOBRIST_PIECES) == (12, 64)
    @test all(isa.(OrbisChessEngine.ZOBRIST_PIECES, UInt64))

    # Check castling array
    @test length(OrbisChessEngine.ZOBRIST_CASTLING) == 16
    @test all(isa.(OrbisChessEngine.ZOBRIST_CASTLING, UInt64))

    # Check en passant array
    @test length(OrbisChessEngine.ZOBRIST_EP) == 8
    @test all(isa.(OrbisChessEngine.ZOBRIST_EP, UInt64))
end

@testset "board structs not equal" begin
    b1 = Board()
    b2 = Board()
    make_move!(b1, Move("e2", "e4"))

    @test b1 != b2

    make_move!(b2, Move("e2", "e4"))
    b1.undo_stack = Vector{UndoInfo}(undef, OrbisChessEngine.MAX_MOVES_PER_GAME)

    @test b1 != b2
end
