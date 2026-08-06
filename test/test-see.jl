using OrbisChessEngine
using Test

@testset "SEE: undefended capture wins the full piece value" begin
    b = Board(fen = "4k3/8/8/8/3p4/4P3/8/4K3 w - - 0 1")
    m = Move("e3", "d4"; capture = Piece.B_PAWN)
    @test OrbisChessEngine.see(b, m) == 100
end

@testset "SEE: equal trade (knight for knight) nets zero" begin
    b = Board(fen = "4k3/8/1p6/2n5/8/3N4/8/4K3 w - - 0 1")
    m = Move("d3", "c5"; capture = Piece.B_KNIGHT)
    @test OrbisChessEngine.see(b, m) == 0
end

@testset "SEE: queen takes a pawn defended by a pawn loses material" begin
    b = Board(fen = "4k3/8/1p6/2p5/8/8/8/3QK3 w - - 0 1")
    m = Move("d1", "c5"; capture = Piece.W_PAWN)
    @test OrbisChessEngine.see(b, m) == -800  # +100 (pawn) - 900 (queen)
end

@testset "SEE: a winning capture backed by a second attacker still wins in full" begin
    # White pawn takes a black knight defended by a black bishop, but
    # White has a rook backing up the pawn: if Black recaptures with the
    # bishop, White's rook wins it right back, so the correct, fully
    # played-out result is Black declining to recapture at all -- White
    # simply wins the knight outright (+300), not a messy partial trade.
    b = Board(fen = "4k3/8/8/2n5/8/2b5/3P4/R3K3 w - - 0 1")
    m = Move("d2", "c3"; capture = Piece.B_BISHOP)
    @test OrbisChessEngine.see(b, m) == 300
end

@testset "SEE: only defender being the king still resolves correctly" begin
    # White queen (b5) takes a black knight (d5) defended only by the
    # black king (c6, diagonally adjacent), with a white rook (a5) lined
    # up behind the queen on the same rank. Recapturing with the king
    # would walk into the rook's attack once the queen's square opens up
    # (illegal -- moving into check), so Black can't actually recapture:
    # White wins the knight outright, not a king-for-queen trade.
    b = Board(fen = "8/8/2k5/RQ1n4/8/8/8/4K3 w - - 0 1")
    m = Move("b5", "d5"; capture = Piece.B_KNIGHT)
    @test OrbisChessEngine.see(b, m) == 300
end

@testset "SEE: en passant captures a pawn" begin
    b = Board(fen = "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
    m = Move("e5", "d6"; en_passant = true)
    @test OrbisChessEngine.see(b, m) == 100
end

@testset "move_ordering_score ranks a winning capture above a losing one" begin
    # White rook can take an undefended pawn on a6 (winning, +100); White
    # queen can take a pawn on c5 defended by a pawn on b6 (losing,
    # -800). Both are real legal moves on the same board -- SEE-based
    # ordering should rank the winning capture higher despite the queen
    # nominally capturing the same-valued piece.
    b = Board(fen = "4k3/8/pp6/2p4Q/8/8/8/R3K3 w - - 0 1")
    legal = generate_legal_moves(b)

    winning = only(
        filter(
            m ->
                m.from == OrbisChessEngine.square_index("a1") &&
                m.to == OrbisChessEngine.square_index("a6"),
            legal,
        ),
    )
    losing = only(
        filter(
            m ->
                m.from == OrbisChessEngine.square_index("h5") &&
                m.to == OrbisChessEngine.square_index("c5"),
            legal,
        ),
    )

    @test OrbisChessEngine.see(b, winning) == 100
    @test OrbisChessEngine.see(b, losing) == -800
    @test OrbisChessEngine.move_ordering_score(b, winning, 0) >
          OrbisChessEngine.move_ordering_score(b, losing, 0)
end

@testset "Quiescence prunes a losing capture instead of searching it" begin
    # The only legal capture available is White's queen taking a pawn on
    # c5 that's defended by a pawn on b6 -- a losing trade (SEE < 0).
    # With bad-capture pruning this capture is skipped entirely, so
    # quiescence should return the stand-pat static eval unchanged rather
    # than searching (and losing material through) the bad capture.
    b = Board(fen = "4k3/8/1p6/2pQ4/8/8/8/4K3 w - - 0 1")
    legal = generate_legal_moves(b)
    @test any(
        m ->
            m.from == OrbisChessEngine.square_index("d5") &&
            m.to == OrbisChessEngine.square_index("c5"),
        legal,
    )

    score = OrbisChessEngine.quiescence(
        b,
        -OrbisChessEngine.MATE_VALUE,
        OrbisChessEngine.MATE_VALUE,
    )
    @test score == evaluate(b)
end
