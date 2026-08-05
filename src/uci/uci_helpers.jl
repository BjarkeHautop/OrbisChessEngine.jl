# See https://www.wbec-ridderkerk.nl/html/UCIProtocol.html
# for the UCI protocol specification
# Need to modify search to support node limits, ponder mode, etc.
# Need to modify game struct to support different time increments for
# white and black, moves to next time control, etc.

# Fallback search depth for "go" with no depth/movetime/wtime/btime given
# (including "go infinite"). True infinite-search-until-stop isn't supported
# yet, since the search runs synchronously and isn't cancellable mid-flight.
const DEFAULT_GO_DEPTH = 6

"""
    to_uci(m::Move) -> String

Format a `Move` in UCI long algebraic notation, e.g. `"e2e4"`, `"e7e8q"`.
Unlike `string(m)` (used for human-readable display), this never uses `"O-O"`
or `"="`, since UCI represents castling as the king's from/to squares and
promotions with a bare lowercase letter.
"""
function to_uci(m::Move)
    s = string(square_name(m.from), square_name(m.to))
    if m.promotion != 0
        s *= lowercase(piece_symbol(m.promotion))
    end
    return s
end

"""
    find_uci_move(board::Board, uci_str::AbstractString) -> Move

Resolve a UCI move string (e.g. `"e2e4"`, `"e7e8q"`, `"e1g1"` for castling)
to the matching legal `Move` on `board`. Throws an `ErrorException` if no
legal move matches.
"""
function find_uci_move(board::Board, uci_str::AbstractString)
    from = square_from_name(uci_str[1:2])
    to = square_from_name(uci_str[3:4])
    promotion_char = length(uci_str) > 4 ? uppercase(uci_str[end]) : nothing

    for m in generate_legal_moves(board)
        m.from != from && continue
        m.to != to && continue
        if promotion_char === nothing
            m.promotion == 0 && return m
        else
            m.promotion != 0 && piece_symbol(m.promotion) == string(promotion_char) &&
                return m
        end
    end
    error("Illegal move '$uci_str'")
end

function get_engine_version()
    proj_path = normpath(joinpath(@__DIR__, "..", "..", "Project.toml"))
    toml_text = read(proj_path, String)
    m = match(r"(?m)^version\s*=\s*\"([^\"]+)\"", toml_text)
    return m.captures[1]
end

function get_authors()
    proj_path = normpath(joinpath(@__DIR__, "..", "..", "Project.toml"))
    toml_text = read(proj_path, String)
    m = match(r"(?m)^\s*authors\s*=\s*\[([^\]]+)\]", toml_text)
    authors_str = m.captures[1]
    authors = [strip(replace(a, "\"" => "")) for a in split(authors_str, ",")]
    return authors
end

function id()
    version = get_engine_version()
    authors = join(get_authors(), ", ")
    println("id name OrbisChessEngine $version")
    println("id author $authors")
end

function handle_uci_command()
    # 1. Print engine identification
    id()  # prints name, version, author

    # 2. Print engine options
    # (none for now)

    # 3. Signal that UCI mode is ready
    println("uciok")
end

function handle_debug()
    println("debugging info")
    # Turn on verbose=true in search function to get more info?
end

function handle_isready()
    println("readyok")
end

function handle_setoption()
    # No options for now
    println("no options available")
end

function handle_register()
    println("register later")
end

function handle_position(command::String)
    tokens = split(command)
    board = nothing

    if tokens[2] == "startpos"
        board = Board()  # initialize starting position
        moves_index = findfirst(isequal("moves"), tokens)
    elseif tokens[2] == "fen"
        # collect FEN tokens (until "moves" or end of line)
        moves_index = findfirst(isequal("moves"), tokens)
        fen_tokens = moves_index === nothing ? tokens[3:end] : tokens[3:(moves_index - 1)]
        fen_string = join(fen_tokens, " ")
        board = Board(fen = fen_string)
    else
        error("invalid position command: must be startpos or fen")
    end

    if moves_index !== nothing
        for mv_str in tokens[(moves_index + 1):end]
            make_move!(board, find_uci_move(board, mv_str))
        end
    end

    return board
end

function handle_go(command::String, board)
    tokens = split(command)  # split by space
    search_params = Dict{String, Any}()

    i = 2  # skip "go"
    while i <= length(tokens)
        token = tokens[i]

        if token == "searchmoves"
            moves = String[]
            i += 1  # skip "searchmoves"
            while i <= length(tokens)
                tok = tokens[i]
                if occursin(r"^[a-h][1-8][a-h][1-8][qrbn]?$", tok) ||
                   uppercase(tok) in ["O-O", "O-O-O"]
                    push!(moves, tok)
                    i += 1
                else
                    break  # stop when we reach something that is NOT a move
                end
            end
            search_params["searchmoves"] = moves
            # All times are in milliseconds
        elseif token == "wtime"
            i += 1
            search_params["wtime"] = parse(Int, tokens[i])
        elseif token == "btime"
            i += 1
            search_params["btime"] = parse(Int, tokens[i])
            # Currently only have shared increment in Game struct
        elseif token == "winc"
            i += 1
            search_params["winc"] = parse(Int, tokens[i])
        elseif token == "binc"
            i += 1
            search_params["binc"] = parse(Int, tokens[i])
            # Number of moves until next time control
        elseif token == "movestogo"
            i += 1
            search_params["movestogo"] = parse(Int, tokens[i])
            # Depth to search
        elseif token == "depth"
            i += 1
            search_params["depth"] = parse(Int, tokens[i])
            # Number of nodes (positions) to search
        elseif token == "nodes"
            i += 1
            search_params["nodes"] = parse(Int, tokens[i])
            # Search for mate in x moves
            # Not implemented yet
        elseif token == "mate"
            i += 1
            search_params["mate"] = parse(Int, tokens[i])
            # Search for exactly this much time
            # Not implemented yet
        elseif token == "movetime"
            i += 1
            search_params["movetime"] = parse(Int, tokens[i])
            # Search until stopped
        elseif token == "infinite"
            search_params["infinite"] = true
            # Pondering mode
            # Not implemented yet
        elseif token == "ponder"
            search_params["ponder"] = true
        else
            # unknown token, skip
        end
        i += 1
    end

    depth = get(search_params, "depth", nothing)
    movetime = get(search_params, "movetime", nothing)
    has_time_control = haskey(search_params, "wtime") || haskey(search_params, "btime")

    if depth !== nothing
        search_depth = depth
        time_budget = something(movetime, typemax(Int))
        max_time_budget = time_budget
    elseif movetime !== nothing
        search_depth = 64
        time_budget = movetime
        max_time_budget = time_budget
    elseif has_time_control
        remaining = board.side_to_move == WHITE ? get(search_params, "wtime", 0) :
                    get(search_params, "btime", 0)
        increment = board.side_to_move == WHITE ? get(search_params, "winc", 0) :
                    get(search_params, "binc", 0)
        movestogo = get(search_params, "movestogo", nothing)
        time_budget, max_time_budget = time_management(remaining, increment, movestogo)
        search_depth = 64
    else
        # Bare "go" / "go infinite": no live-cancellable search yet, so fall
        # back to a fixed, safe depth instead of searching unboundedly.
        search_depth = DEFAULT_GO_DEPTH
        time_budget = typemax(Int)
        max_time_budget = time_budget
    end

    result = search(board; depth = search_depth, time_budget = time_budget,
        max_time_budget = max_time_budget, uci_info = true)
    println(result === nothing ? "bestmove 0000" : "bestmove $(to_uci(result.move))")
end

function handle_stop()
    # No-op: search runs synchronously and always finishes before the next
    # command is read, so there is never an in-flight search to interrupt.
end

function handle_ponderhit()
    # The user has played the expected move. This will be sent if the engine was told to ponder on the same move
    # the user has played. The engine should continue searching but switch from pondering to normal search.
    # No-op: pondering isn't implemented, so there is nothing to switch over.
end

function handle_quit()
    # No-op: the "quit" token is handled by the run_uci() loop itself, which
    # breaks out and returns rather than calling exit() from library code.
end
