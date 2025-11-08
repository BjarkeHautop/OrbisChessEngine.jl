using OrbisChessEngine
using Test

@testset "castling works" begin
    b = Board()

    # Clear pieces between king and rook for castling
    b.bitboards[Piece.W_BISHOP] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_BISHOP], OrbisChessEngine.square_index(6, 1))
    b.bitboards[Piece.W_KNIGHT] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_KNIGHT], OrbisChessEngine.square_index(7, 1))

    # Generate legal moves for white
    legal_moves = generate_legal_moves(b)

    # e1 → g1 (short castle)
    castling_move = Move("e1", "g1"; castling = 1)
    @test castling_move in legal_moves

    # Make the castling move
    make_move!(b, castling_move)

    # Verify king and rook positions after castling
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.W_KING], OrbisChessEngine.square_index(7, 1))  # King on g1
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.W_ROOK], OrbisChessEngine.square_index(6, 1))  # Rook on f1
end

@testset "King move generation" begin
    b = Board()

    # Remove e2, f2 pawn, and pieces for castling
    b.bitboards[Piece.W_PAWN] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_PAWN], OrbisChessEngine.square_index(5, 2))
    b.bitboards[Piece.W_PAWN] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_PAWN], OrbisChessEngine.square_index(6, 2))
    b.bitboards[Piece.W_KNIGHT] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_KNIGHT], OrbisChessEngine.square_index(2, 1))
    b.bitboards[Piece.W_BISHOP] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_BISHOP], OrbisChessEngine.square_index(3, 1))
    b.bitboards[Piece.W_QUEEN] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_QUEEN], OrbisChessEngine.square_index(4, 1))
    b.bitboards[Piece.W_BISHOP] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_BISHOP], OrbisChessEngine.square_index(6, 1))
    b.bitboards[Piece.W_KNIGHT] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_KNIGHT], OrbisChessEngine.square_index(7, 1))

    king_moves = OrbisChessEngine.generate_king_moves(b)

    expected_moves = [
        Move("e1", "e2"),
        Move("e1", "f1"),
        Move("e1", "f2"),
        Move("e1", "g1"; castling = 1), # short castle
        Move("e1", "d1"),
        Move("e1", "c1"; castling = 2)  # long castle
    ]

    for em in expected_moves
        @test em in king_moves
    end

    # Add a black rook attacking f1 to block short castling
    b.bitboards[Piece.B_ROOK] = OrbisChessEngine.setbit(
        b.bitboards[Piece.B_ROOK], OrbisChessEngine.square_index(6, 4))  # f4 rook
    legal_moves = generate_legal_moves(b)
    # e1 → g1 (short castle) should no longer be allowed
    short_castle = Move("e1", "g1"; castling = 1)
    @test !(short_castle in legal_moves)
    # e1 → c1 (long castle) should still be allowed
    long_castle = Move("e1", "c1"; castling = 2)
    @test long_castle in legal_moves
end

@testset "King move disables castling" begin
    b = Board()

    # Clear pieces between king and rook for castling
    b.bitboards[Piece.W_BISHOP] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_BISHOP], OrbisChessEngine.square_index(6, 1))
    b.bitboards[Piece.W_KNIGHT] = OrbisChessEngine.clearbit(
        b.bitboards[Piece.W_KNIGHT], OrbisChessEngine.square_index(7, 1))

    # Step 1: move king to f1
    m1 = Move("e1", "f1")
    make_move!(b, m1)

    b.side_to_move = WHITE

    # Step 2: move king back to e1
    m2 = Move("f1", "e1")
    make_move!(b, m2)

    b.side_to_move = WHITE

    # Generate legal moves for white
    legal_moves = generate_legal_moves(b)

    # e1 → g1 (short castle) should no longer be allowed
    castling_move = Move("e1", "g1"; castling = 1)
    @test !(castling_move in legal_moves)

    # King should still be able to move normally
    @test Move("e1", "f1") in legal_moves
end

@testset "Castling rights disabled captures" begin
    b = Board()
    @test b.castling_rights == 0x0f

    m1 = Move("d1", "a8"; capture = Piece.B_ROOK)
    make_move!(b, m1)
    @test b.castling_rights == 0x07

    undo_move!(b, m1)
    @test b.castling_rights == 0x0f
    make_move!(b, m1)
    @test b.castling_rights == 0x07

    m2 = Move("d8", "a1"; capture = Piece.W_ROOK)
    make_move!(b, m2)
    @test b.castling_rights == 0x05
    undo_move!(b, m2)
    @test b.castling_rights == 0x07
    make_move!(b, m2)
    @test b.castling_rights == 0x05

    m3 = Move("a8", "h8"; capture = Piece.B_ROOK)
    make_move!(b, m3)
    @test b.castling_rights == 0x01
    undo_move!(b, m3)
    @test b.castling_rights == 0x05
    make_move!(b, m3)
    @test b.castling_rights == 0x01

    m4 = Move("a1", "h1"; capture = Piece.W_ROOK)
    make_move!(b, m4)
    @test b.castling_rights == 0x00
    undo_move!(b, m4)
    @test b.castling_rights == 0x01
    make_move!(b, m4)
    @test b.castling_rights == 0x00
end

@testset "All castling works correctly" begin
    b = Board(fen = "r3k2r/3p1p2/8/8/8/8/8/R3K2R w KQkq - 0 1")

    # White short
    mv = Move("e1", "g1"; castling = 1)
    @test mv in generate_legal_moves(b)

    make_move!(b, mv)
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.W_KING], OrbisChessEngine.square_index(7, 1))  # King on g1
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.W_ROOK], OrbisChessEngine.square_index(6, 1))  # Rook on f1

    undo_move!(b, mv)
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.W_KING], OrbisChessEngine.square_index(5, 1))  # King back on e1
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.W_ROOK], OrbisChessEngine.square_index(8, 1))  # Rook back on h1

    # White long
    mv = Move("e1", "c1"; castling = 2)
    @test mv in generate_legal_moves(b)

    make_move!(b, mv)
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.W_KING], OrbisChessEngine.square_index(3, 1))  # King on c1
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.W_ROOK], OrbisChessEngine.square_index(4, 1))  # Rook on d1
    undo_move!(b, mv)
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.W_KING], OrbisChessEngine.square_index(5, 1))  # King back on e1
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.W_ROOK], OrbisChessEngine.square_index(1, 1))  # Rook back on a1

    # Black long
    b.side_to_move = BLACK
    mv = Move("e8", "c8"; castling = 2)
    @test mv in generate_legal_moves(b)

    make_move!(b, mv)
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.B_KING], OrbisChessEngine.square_index(3, 8))  # King on c8
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.B_ROOK], OrbisChessEngine.square_index(4, 8))  # Rook on d8

    undo_move!(b, mv)
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.B_KING], OrbisChessEngine.square_index(5, 8))  # King back on e8
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.B_ROOK], OrbisChessEngine.square_index(1, 8))  # Rook back on a8

    # Black short
    mv = Move("e8", "g8"; castling = 1)
    @test mv in generate_legal_moves(b)

    make_move!(b, mv)
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.B_KING], OrbisChessEngine.square_index(7, 8))  # King on g8
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.B_ROOK], OrbisChessEngine.square_index(6, 8))  # Rook on f8

    undo_move!(b, mv)
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.B_KING], OrbisChessEngine.square_index(5, 8))  # King back on e8
    @test OrbisChessEngine.testbit(
        b.bitboards[Piece.B_ROOK], OrbisChessEngine.square_index(8, 8))  # Rook back on h8
end

@testset "King attack masks" begin
    OrbisChessEngine.init_king_masks!()

    # a1; Neighbors: b1 (bit 1), a2 (bit 8), b2 (bit 9)
    @test OrbisChessEngine.king_attack_masks[1] == 0x302

    # h1; Neighbors: g1 (bit 6), g2 (bit 14), h2 (bit 15)
    @test OrbisChessEngine.king_attack_masks[8] == 0xC040

    # a8; Neighbors: a7 (bit 48), b7 (bit 49), b8 (bit 57)
    @test OrbisChessEngine.king_attack_masks[57] == 0x0203000000000000

    # h8; Neighbors: g7 (bit 54), g8 (bit 62), h7 (bit 55)
    @test OrbisChessEngine.king_attack_masks[64] == 0x40c0000000000000

    # d4; Neighbors: c3, c4, c5, d3, d5, e3, e4, e5
    @test OrbisChessEngine.king_attack_masks[28] == 0x0000001c141c0000
end
