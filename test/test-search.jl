using OrbisChessEngine
using Test

@testset "Search Finds Scholar Mate" begin
    b = Board()
    moves = [Move("f2", "f3"), Move("e7", "e5"), Move("g2", "g4")]

    for m in moves
        make_move!(b, m)
    end
    result = search(b; depth = 2, opening_book = nothing)
    @test result.score < -10_000  # Checkmate
    @test result.move == Move("d8", "h4")
end

@testset "Search with time constraint" begin
    b = Board()

    m1 = Move("e2", "e4")
    make_move!(b, m1)
    M2 = Move("d7", "d5")
    make_move!(b, M2)

    time_before = time_ns() ÷ 1_000_000
    result = search(b; depth = 10, opening_book = nothing, time_budget = 1000)
    time_after = time_ns() ÷ 1_000_000
    @test (time_after - time_before) <= 1500  # Allow some overhead
end

@testset "Search verbose works" begin
    b = Board()

    result = search(b; depth = 2, opening_book = nothing, verbose = true)
    @test result.move !== nothing
end

@testset "Search works in random position" begin
    b = Board(fen = "rnbq1rk1/pp4bp/2pp1np1/3Ppp2/2P5/2N2NP1/PP2PPBP/R1BQ1RK1 w - e6 0 1")

    result = search(b; depth = 4, opening_book = nothing)
    @test true  # Just ensure it completes without error
end

@testset "Search does not hang a piece on a truncated iteration (regression)" begin
    # Position from a cutechess-cli game against Stockfish:
    # White's knight on d4 is undefended and attacked
    # by the bishop on c5.
    # Orbis actually played 11.Bxa6?? here and went on to lose.
    b = Board(fen = "r1bqk2r/1p1n1ppp/p4n2/2bP4/3N1P2/8/PP1NB1PP/R1BQK2R w KQkq - 1 11")
    result = search(b; depth = 6, opening_book = nothing, time_budget = 1000)
    @test result !== nothing

    make_move!(b, result.move)
    d4 = OrbisChessEngine.square_from_name("d4")
    if OrbisChessEngine.piece_at(b, d4) == Piece.W_KNIGHT
        # The knight is still on d4: it must no longer be a free capture —
        # either White now defends it, or Black no longer attacks it.
        @test OrbisChessEngine.square_attacked(b, d4, WHITE) ||
              !OrbisChessEngine.square_attacked(b, d4, BLACK)
    end
end

@testset "Search works in stalemate position" begin
    b = Board(fen = "4k3/4P3/4K3/8/8/8/8/8 b - - 0 1")
    output = search(b; depth = 1, opening_book = nothing, verbose = true)

    @test isnothing(output)
end

@testset "Search works in mate position" begin
    b = Board(fen = "4k3/3PP3/4K3/8/8/8/8/8 b - - 0 1")
    output = search(b; depth = 1, opening_book = nothing, verbose = true)

    @test isnothing(output)
end

@testset "Search still returns a move when the root is already a legal draw (regression)" begin
    # Unlike checkmate/stalemate, a position that's a draw by insufficient
    # material/threefold/fifty-move still has legal moves. The engine
    # must still play one instead of returning no move at all, which a
    # UCI tournament manager treats as an illegal-move forfeit. Found via
    # a K+N vs K+B self-play game reaching this exact FEN.
    b = Board(fen = "7b/8/4N3/8/4K3/2k5/8/8 w - - 0 151")
    @test game_status(b) == :draw_insufficient_material

    result = search(b; depth = 10, opening_book = nothing, time_budget = 2000)
    @test result !== nothing
    @test result.move in generate_legal_moves(b)
end

@testset "Transposition Table Tests" begin
    OrbisChessEngine.tt_clear!()  # ensure empty TT before tests

    # Dummy moves for testing
    move1 = OrbisChessEngine.NO_MOVE  # Sentinel for no move
    move2 = Move("e2", "e4")
    move3 = Move("d2", "d4")

    # Hash values (fake Zobrist)
    h1 = UInt64(0x1234)
    h2 = UInt64(0x5678)

    # --- Test 1: Empty slot returns false ---
    val, move, hit = OrbisChessEngine.tt_probe_raw(h1)
    @test hit == false
    @test val == 0
    @test move === OrbisChessEngine.NO_MOVE

    # --- Test 2: Store and retrieve exact entry ---
    OrbisChessEngine.tt_store(h1, 42, 5, OrbisChessEngine.EXACT, move2)
    val, move, hit = OrbisChessEngine.tt_probe_raw(h1)
    @test hit == true
    @test val == 42
    @test move === move2

    # --- Test 3: Overwrite lower depth does not replace ---
    OrbisChessEngine.tt_store(h1, 100, 4, OrbisChessEngine.EXACT, move3)  # depth < existing
    val, move, hit = OrbisChessEngine.tt_probe_raw(h1)
    @test val == 42
    @test move === move2

    # --- Test 4: Overwrite equal or higher depth replaces ---
    OrbisChessEngine.tt_store(h1, 55, 5, OrbisChessEngine.EXACT, move3)
    val, move, hit = OrbisChessEngine.tt_probe_raw(h1)
    @test val == 55
    @test move === move3

    OrbisChessEngine.tt_store(h1, 77, 6, OrbisChessEngine.LOWERBOUND, move2)
    val, move, hit = OrbisChessEngine.tt_probe_raw(h1)
    @test val == 77
    @test move === move2

    # --- Test 5: NO_MOVE sentinel works ---
    h3 = UInt64(0x9abc)
    OrbisChessEngine.tt_store(h3, 10, 2, OrbisChessEngine.EXACT, OrbisChessEngine.NO_MOVE)
    val, move, hit = OrbisChessEngine.tt_probe_raw(h3)
    @test hit == true
    @test move === OrbisChessEngine.NO_MOVE
end

@testset "Quiescence returns mate score instead of static eval when in check with no captures (regression)" begin
    b = Board(fen = "4k3/3PP3/4K3/8/8/8/8/8 b - - 0 1")
    @test OrbisChessEngine.in_check(b, BLACK)
    @test isempty(generate_legal_moves(b))

    score = OrbisChessEngine.quiescence(
        b, -OrbisChessEngine.MATE_VALUE, OrbisChessEngine.MATE_VALUE)
    @test score == OrbisChessEngine.MATE_VALUE  # Black is mated; score is from White's POV
end

@testset "Quiescence searches non-capturing check evasions instead of standing pat (regression)" begin
    # White king in check along the e-file from a lone black queen, with no
    # blocking piece and nothing that can capture the queen -- the only
    # legal replies are king moves (all non-captures). Before the fix,
    # quiescence's captures-only move generation found 0 moves here and
    # returned evaluate(board) directly, without trying any king move.
    b = Board(fen = "k3q3/8/8/8/8/8/8/4K3 w - - 0 1")
    @test OrbisChessEngine.in_check(b, WHITE)

    legal = generate_legal_moves(b)
    @test length(legal) > 0
    @test all(m -> m.capture == 0, legal)  # no legal captures available

    expected = maximum(legal) do m
        child = deepcopy(b)
        make_move!(child, m)
        evaluate(child)
    end

    score = OrbisChessEngine.quiescence(
        b, -OrbisChessEngine.MATE_VALUE, OrbisChessEngine.MATE_VALUE)
    @test score == expected
end

@testset "TT mate scores are re-anchored by ply, not reused as-is" begin
    OrbisChessEngine.tt_clear!()
    h = UInt64(0xdead_beef)
    mv = Move("e2", "e4")

    remaining = 2   # plies from this position itself to checkmate
    stored_ply = 3  # ply of the node that stored it, in the search that found it
    OrbisChessEngine.tt_store(
        h, OrbisChessEngine.MATE_VALUE - (stored_ply + remaining),
        5, OrbisChessEngine.EXACT, mv, stored_ply)

    # Retrieved via transposition at different plies, in different (later)
    # searches: the position is still "mate in `remaining` plies from
    # itself", so the score must come back re-anchored to each new ply.
    for new_ply in (0, 7)
        val, move, hit = OrbisChessEngine.tt_probe(
            h, 5, -OrbisChessEngine.MATE_VALUE, OrbisChessEngine.MATE_VALUE, new_ply)
        @test hit
        @test val == OrbisChessEngine.MATE_VALUE - (new_ply + remaining)
        @test move == mv
    end
end
