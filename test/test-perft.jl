using OrbisChessEngine
using Test

# Takes below 0.5 sec for depth 1 to 5 on my machine
@testset "perft tests" begin
    b = Board()
    @test perft(b, 0) == 1
    @test perft(b, 1) == 20
    @test perft(b, 2) == 400
    @test perft(b, 3) == 8902
    @test perft(b, 4) == 197_281
    @test perft(b, 5) == 4_865_609
end

# Takes below 0.1 sec for depth 1 to 5 on my machine using 8 threads
@testset "fast perft tests" begin
    b = Board()
    @test perft_fast(b, 0) == 1
    @test perft_fast(b, 1) == 20
    @test perft_fast(b, 2) == 400
    @test perft_fast(b, 3) == 8902
    @test perft_fast(b, 4) == 197_281
    @test perft_fast(b, 5) == 4_865_609
    # @test perft_fast(b, 6) == 119_060_324
    # @test perft_fast(b, 7) == 3_195_901_860
end

@testset "Split indicies tests" begin
    @test OrbisChessEngine.split_indices(10, 2) == [1:5, 6:10]
    @test OrbisChessEngine.split_indices(10, 3) == [1:4, 5:7, 8:10]
end

@testset "perft bishop magic tests" begin
    b = Board()
    @test perft_bishop_magic(b, 0) == 1
    @test perft_bishop_magic(b, 1) == 20
    @test perft_bishop_magic(b, 2) == 400
    @test perft_bishop_magic(b, 3) == 8902
    @test perft_bishop_magic(b, 4) == 197_281
    @test perft_bishop_magic(b, 5) == 4_865_609
end

# Capturing en passant can clear two squares on the same rank/file/diagonal
@testset "perft en passant discovered check tests" begin
    b = Board(fen = "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
    @test perft(b, 1) == 14
    @test perft(b, 2) == 191
    @test perft(b, 3) == 2812
    @test perft(b, 4) == 43_238
    @test perft(b, 5) == 674_624
end
