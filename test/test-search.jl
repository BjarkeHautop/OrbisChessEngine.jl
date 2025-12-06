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
