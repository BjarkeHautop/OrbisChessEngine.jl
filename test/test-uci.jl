using Test
using OrbisChessEngine

@testset "handle_uci_command output" begin
    original_stdout = stdout
    (read_pipe, write_pipe) = redirect_stdout()  # capture stdout

    OrbisChessEngine.handle_uci_command()

    redirect_stdout(original_stdout)
    close(write_pipe)

    output = read(read_pipe, String)
    lines = split(strip(output), '\n')

    @test length(lines) == 3

    # Line 1: check engine name and version
    @test occursin(r"OrbisChessEngine \d+\.\d+\.\d+(?:-DEV)?", lines[1])

    # Line 2: check author
    @test occursin("Bjarke Hautop Kristensen", lines[2])

    # Line 3: check uciok
    @test occursin("uciok", lines[3])
end

@testset "Call various uci_helpers" begin
    # They do nothing for now, just ensure no errors
    OrbisChessEngine.handle_debug()
    OrbisChessEngine.handle_isready()
    OrbisChessEngine.handle_setoption()
    OrbisChessEngine.handle_register()
    OrbisChessEngine.handle_stop()
    OrbisChessEngine.handle_ponderhit()
    @test true
end

@testset "handle_position" begin
    board = OrbisChessEngine.handle_position("position startpos")
    @test OrbisChessEngine.position_equal(Board(), board)

    fen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
    board = OrbisChessEngine.handle_position("position fen $fen")
    @test OrbisChessEngine.position_equal(Board(fen = fen), board)

    @test_throws ErrorException OrbisChessEngine.handle_position("position invalidcommand")
end

@testset "handle_position with moves" begin
    board = OrbisChessEngine.handle_position("position startpos moves e2e4 e7e5")
    @test board == apply_moves(Board(), "e2e4", "e7e5")

    # Castling is sent as the king's squares in UCI, not "O-O"
    fen = "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"
    board = OrbisChessEngine.handle_position("position fen $fen moves e1g1")
    @test board == apply_moves(Board(fen = fen), "O-O")

    # Promotion is a bare lowercase letter, not "=Q"
    fen2 = "k7/4P3/8/8/8/8/8/4K3 w - - 0 1"
    board = OrbisChessEngine.handle_position("position fen $fen2 moves e7e8q")
    @test board == apply_moves(Board(fen = fen2), "e7e8=Q")

    @test_throws ErrorException OrbisChessEngine.handle_position(
        "position startpos moves e2e5",
    )
end

@testset "to_uci / find_uci_move" begin
    board = Board()
    mv = OrbisChessEngine.find_uci_move(board, "e2e4")
    @test OrbisChessEngine.to_uci(mv) == "e2e4"
    @test mv == Move(board, "e2e4")

    fen = "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"
    board2 = Board(fen = fen)
    castling_mv = OrbisChessEngine.find_uci_move(board2, "e1g1")
    @test OrbisChessEngine.to_uci(castling_mv) == "e1g1"
    @test castling_mv == Move(board2, "O-O")

    fen2 = "k7/4P3/8/8/8/8/8/4K3 w - - 0 1"
    board3 = Board(fen = fen2)
    promo_mv = OrbisChessEngine.find_uci_move(board3, "e7e8q")
    @test OrbisChessEngine.to_uci(promo_mv) == "e7e8q"
    @test promo_mv.promotion == Piece.W_QUEEN

    @test_throws ErrorException OrbisChessEngine.find_uci_move(board, "e2e5")
end

@testset "handle_go" begin
    b = Board()
    command =
        "go searchmoves e2e4 d7d5 e4d5 ponder e2e4 wtime " *
        "30000 btime 30000 winc 100 binc 100 movestogo 5 " *
        "depth 3 nodes 10000 mate 3 movetime 300 infinite " *
        "unknowncommand"

    original_stdout = stdout
    (read_pipe, write_pipe) = redirect_stdout()
    OrbisChessEngine.handle_go(command, b)
    redirect_stdout(original_stdout)
    close(write_pipe)

    output = strip(read(read_pipe, String))
    @test occursin(r"^bestmove [a-h][1-8][a-h][1-8][qrbn]?$", output)
end

@testset "handle_go depth-only and movetime-only" begin
    b = Board()

    for command in ("go depth 2", "go movetime 200")
        original_stdout = stdout
        (read_pipe, write_pipe) = redirect_stdout()
        OrbisChessEngine.handle_go(command, b)
        redirect_stdout(original_stdout)
        close(write_pipe)

        output = strip(read(read_pipe, String))
        @test occursin(r"^bestmove [a-h][1-8][a-h][1-8][qrbn]?$", output)
    end
end

@testset "run_uci end-to-end" begin
    original_stdout = stdout
    original_stdin = stdin
    (out_read, out_write) = redirect_stdout()
    (in_read, in_write) = redirect_stdin()

    script = "uci\nisready\nposition startpos moves e2e4 e7e5\ngo depth 2\nquit\n"
    write(in_write, script)
    close(in_write)

    OrbisChessEngine.run_uci()

    redirect_stdout(original_stdout)
    redirect_stdin(original_stdin)
    close(out_write)

    output = read(out_read, String)
    @test occursin("uciok", output)
    @test occursin("readyok", output)
    @test occursin(r"bestmove [a-h][1-8][a-h][1-8][qrbn]?", output)
end
