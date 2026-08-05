using OrbisChessEngine
using Test

@testset "Game api" begin
    g = Game()
    new_g = Game("3+2")

    @test g.board == new_g.board
    @test g.white_time == new_g.white_time == 180_000
    @test g.black_time == new_g.black_time == 180_000
    @test g.increment == new_g.increment == 2000
end

@testset "Move api" begin
    b = Board()
    m = Move(b, "e2e4")
    @test m.from == 12
    @test m.to == 28
    @test string(m) == "e2e4"

    m2 = Move(b, "e7e8=Q")
    @test m2.from == 52
    @test m2.to == 60
    @test m2.promotion == Piece.W_QUEEN
    @test string(m2) == "e7e8=Q"

    m3 = Move(b, "e7e8=R")
    @test m3.from == 52
    @test m3.to == 60
    @test m3.promotion == Piece.W_ROOK
    @test string(m3) == "e7e8=R"

    m4 = Move(b, "e7e8=B")
    @test m4.from == 52
    @test m4.to == 60
    @test m4.promotion == Piece.W_BISHOP
    @test string(m4) == "e7e8=B"

    m5 = Move(b, "e7e8=N")
    @test m5.from == 52
    @test m5.to == 60
    @test m5.promotion == Piece.W_KNIGHT
    @test string(m5) == "e7e8=N"

    # Promotion piece color should match the side to move, not the piece
    # actually standing on the from-square (Move() does not validate legality).
    b_black = Board(fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1")
    m2_black = Move(b_black, "e7e8=Q")
    @test m2_black.promotion == Piece.B_QUEEN

    m6 = Move(b, "O-O")
    @test m6.from == 4
    @test m6.to == 6
    @test m6.castling == 1
    @test string(m6) == "O-O"

    m7 = Move(b, "O-O-O")
    @test m7.from == 4
    @test m7.to == 2
    @test m7.castling == 2
    @test string(m7) == "O-O-O"

    @test_throws ErrorException Move(b, "e7e8=Z")

    # En passant move
    make_move!(b, Move(b, "e2e4"))
    make_move!(b, Move(b, "a7a6"))
    make_move!(b, Move(b, "e4e5"))
    make_move!(b, Move(b, "d7d5"))
    m_ep = Move(b, "e5d6")
    @test m_ep.from == 36
    @test m_ep.to == 43
    @test m_ep.en_passant == true
    @test string(m_ep) == "e5d6"
end

@testset "Move api works with make_move" begin
    b = Board()
    m = Move(b, "e2e4")
    new_b = make_move(b, m)
    make_move!(b, m)
    @test OrbisChessEngine.piece_at(b, 28) == OrbisChessEngine.piece_at(new_b, 28) ==
          Piece.W_PAWN
    @test OrbisChessEngine.piece_at(b, 12) == OrbisChessEngine.piece_at(new_b, 12) == 0
end

@testset "Piece symbol tests" begin
    @test OrbisChessEngine.piece_symbol(Piece.W_QUEEN) == "Q"
    @test OrbisChessEngine.piece_symbol(Piece.B_KNIGHT) == "N"
    @test OrbisChessEngine.piece_symbol(0) == ""
end
