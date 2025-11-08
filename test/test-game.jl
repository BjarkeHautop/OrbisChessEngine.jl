using OrbisChessEngine
using Test

@testset "Game Time Management" begin
    game = Game(minutes = 0.5, increment = 2)

    @test isa(game, Game)
    @test game.white_time == 0.5 * 60 * 1000
    @test game.black_time == 0.5 * 60 * 1000
    @test game.increment == 2000

    opt_time, max_time = OrbisChessEngine.allocate_time(game)
    @test isa(opt_time, Int)
    @test isa(max_time, Int)
    @test opt_time > 0
    @test max_time > opt_time

    # Test make_timed_move!
    old_white_time = game.white_time
    make_timed_move!(game; opening_book = nothing)
    @test game.board.side_to_move == BLACK
    @test game.white_time < old_white_time + game.increment  # elapsed time subtracted

    old_black_time = game.black_time
    make_timed_move!(game; opening_book = nothing)
    @test game.board.side_to_move == WHITE
    @test game.black_time < old_black_time + game.increment
end

@testset "Time management heuristic" begin
    opt_time, max_time = OrbisChessEngine.time_management(20000, 2000)
    @test opt_time == 20000 ÷ 30 + (2000 * 3) ÷ 5
    @test max_time == (opt_time * 15) ÷ 10
    opt_time, max_time = OrbisChessEngine.time_management(1000, 0)
    @test opt_time == 1000 ÷ 30
    @test max_time == (opt_time * 15) ÷ 10
end

@testset "Search with time respects allocation" begin
    game = Game(minutes = 0.1, increment = 0)
    make_timed_move!(game; opening_book = nothing)

    # Should have spent at least 6000 ms / 30 = 200ms and at most 1.5 * 2000ms = 300ms
    @test game.white_time <= 5800
    @test game.white_time >= 5650 # allow some margin
end

@testset "Search with time opening book move" begin
    game = Game(minutes = 1, increment = 0)
    make_timed_move!(game)

    # Should have played an opening book move and not spent any time
    @test game.white_time > 59000
    @test game.board.side_to_move == BLACK
end

@testset "Search with time Fools mate" begin
    # Fool's mate position after 1. f3 e5 2. g4 Qh4#
    game = Game(fen = "rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq g3 0 1")
    make_timed_move!(game; opening_book = nothing)

    # Should have played Qh4#
    @test game_status(game.board) == :checkmate_black
end

@testset "Search with time verbose works" begin
    game = Game(minutes = 1, increment = 0)
    make_timed_move!(game; opening_book = nothing, verbose = true)
    @test game.board.side_to_move == BLACK
end

@testset "Search with time non mutating" begin
    game = Game(minutes = 1, increment = 0)
    result = search_with_time(game; max_depth = 4, opening_book = nothing, verbose = false)
    @test isa(result, SearchResult)
    @test result.move !== nothing
    @test game.board.side_to_move == WHITE  # game not mutated
end

@testset "Make timed move non mutating" begin
    game = Game(minutes = 1, increment = 0)
    old_board = deepcopy(game.board)
    make_timed_move(game)
    @test game.board.side_to_move == WHITE  # game not mutated
    @test game.board == old_board  # board unchanged
end

@testset "Make timed move no time left" begin
    game = Game(minutes = 0, increment = 0)
    old_board = deepcopy(game.board)
    make_timed_move!(game; opening_book = nothing, verbose = true)
    @test game.board == old_board  # no move made
    @test game.white_time == 0
end
