using OrbisChessEngine
using Test
using Preferences

@testset "plot board" begin
    b = Board()
    g = Game()

    # Expect no error
    plot(b)
    plot(b; board_orientation = :black)

    plot(g)
    plot(g; board_orientation = :black)

    set_preferences!(
        OrbisChessEngine,
        "theme" => "light",
        force = true
    )
    plot(b)
    plot(g)

    set_preferences!(
        OrbisChessEngine,
        "theme" => "dark",
        force = true
    )
    @test true
end

@testset "show board" begin
    b = Board()
    g = Game()

    # Expect no error
    display_board = show(b)
    display_game = show(g)
    @test true
end
