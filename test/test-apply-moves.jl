using OrbisChessEngine
using Test

@testset "Apply moves works" begin
    board = Board()
    new_board = apply_moves(board, "e2e4", "e7e5")
    apply_moves!(board, "e2e4", "e7e5")

    @test board == new_board
end

@testset "Apply moves errors on illegal moves" begin
    board = Board()
    @test_throws ErrorException apply_moves(board, "e2e4", "e7e5", "e4e5")
    @test_throws ErrorException apply_moves!(board, "e2e4", "e7e5", "e4e5")
end
