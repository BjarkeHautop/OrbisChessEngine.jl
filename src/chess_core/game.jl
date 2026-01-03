# Game struct used for games with time control

"""
    Game

A struct representing a chess game with time control.

- board: The current state of the chess board.
- white_time: Time remaining for White in milliseconds.
- black_time: Time remaining for Black in milliseconds.
- increment: Time increment per move in milliseconds.
"""
mutable struct Game
    board::Board
    white_time::Int   # milliseconds remaining
    black_time::Int
    increment::Int    # per-move increment in ms
end

function time_management(remaining_ms::Int, increment_ms::Int)
    # Base heuristic
    base = remaining_ms ÷ 30
    bonus = (increment_ms * 3) ÷ 5    # 0.6 * increment

    opt_time = base + bonus

    # Max time = 1.5 * opt_time
    max_time = (opt_time * 15) ÷ 10

    return opt_time, max_time
end

function allocate_time(game::Game)
    side = game.board.side_to_move
    remaining = side == WHITE ? game.white_time : game.black_time
    return time_management(remaining, game.increment)
end

function search_with_time(
        game::Game;
        max_depth::Int = 64,
        opening_book::Union{Nothing, PolyglotBook} = KOMODO_OPENING_BOOK,
        verbose::Bool = false
)
    # --- Time management ---
    allocated_opt, allocated_max = allocate_time(game)
    opt_stop_time = Int(time_ns() ÷ 1_000_000 + allocated_opt)
    max_stop_time = Int(time_ns() ÷ 1_000_000 + allocated_max)

    if verbose
        println("Allocated time (ms): optimal = ", allocated_opt,
            " max = ", allocated_max)
    end

    # --- Run iterative deepening ---
    result = search_root(
        game.board,
        max_depth;
        opt_stop_time = opt_stop_time,
        max_stop_time = max_stop_time,
        opening_book = opening_book,
        verbose = verbose
    )
    return result
end

"""
    engine_move!(game::Game; opening_book::Union{Nothing, PolyglotBook}=KOMODO_OPENING_BOOK, verbose=false)

Searches for and makes a move for the current player, updating the Game struct with the updated board and time remaining.
- `game`: Game struct
- `opening_book`: Optional PolyglotBook for opening moves
- `verbose`: If true, print move details and time used

The time allocated for the search is done automatically based on remaining time and increment.
See [`search`](@ref) for details on how the search is performed.
"""
function engine_move!(
        game::Game;
        opening_book::Union{Nothing, PolyglotBook} = KOMODO_OPENING_BOOK,
        verbose = false
)
    tt_clear!()  # reset TT for this search

    start_time = time_ns() ÷ 1_000_000
    result = search_with_time(game; opening_book = opening_book, verbose = verbose)
    elapsed = (time_ns() ÷ 1_000_000) - start_time

    if result.move === NO_MOVE
        if verbose
            println("search returned no move")
        end
        return nothing
    end

    side_moved = game.board.side_to_move

    make_move!(game.board, result.move)

    if side_moved == WHITE
        game.white_time -= elapsed
        game.white_time += game.increment
    else
        game.black_time -= elapsed
        game.black_time += game.increment
    end
    if verbose
        println("Move made: ", result.move, " Score: ",
            result.score, " Time used (ms): ", elapsed)
        println("White time (ms): ", game.white_time, " Black time (ms): ", game.black_time)
    end
end

# Non-mutating version
"""
    engine_move(game::Game; opening_book::Union{Nothing, PolyglotBook}=KOMODO_OPENING_BOOK, verbose=false) -> Game

Searches for and makes a move for the current player, returning a new Game struct with the updated board and time remaining.
- `game`: Game struct
- `opening_book`: Optional PolyglotBook for opening moves
- `verbose`: If true, print move details and time used

The time allocated for the search is done automatically based on remaining time and increment.
See [`search`](@ref) for details on how the search is performed.
"""
function engine_move(
        game::Game;
        opening_book::Union{Nothing, PolyglotBook} = KOMODO_OPENING_BOOK,
        verbose = false
)
    game_copy = deepcopy(game)
    engine_move!(game_copy; opening_book = opening_book, verbose = verbose)
    return game_copy
end

"""
Check for threefold repetition
- `board`: Board struct
Returns: Bool
"""
function is_threefold_repetition(board::Board)
    n = 0
    # Update to not use findlast
    last_index = findlast(!=(0), board.position_history)
    last_key = board.position_history[last_index]
    for k in board.position_history
        if k == 0
            break  # stop at unused entries
        end
        n += k == last_key ? 1 : 0
    end
    return n >= 3
end

"""
Check for fifty-move rule
- `board`: Board struct
Returns: Bool
"""
function is_fifty_move_rule(board::Board)
    return board.halfmove_clock >= 100  # 100 plies = 50 full moves
end

"""
    is_insufficient_material(board::Board) -> Bool

Check for insufficient material to mate
- `board`: Board struct
"""
function is_insufficient_material(board::Board)
    # Count pieces using bitboards
    function count_bits(bb::UInt64)
        return count_ones(bb)
    end

    # Quick check: any pawns, rooks, or queens → material is sufficient
    if count_bits(board.bitboards[Piece.W_PAWN]) > 0 ||
       count_bits(board.bitboards[Piece.B_PAWN]) > 0 ||
       count_bits(board.bitboards[Piece.W_ROOK]) > 0 ||
       count_bits(board.bitboards[Piece.B_ROOK]) > 0 ||
       count_bits(board.bitboards[Piece.W_QUEEN]) > 0 ||
       count_bits(board.bitboards[Piece.B_QUEEN]) > 0
        return false
    end

    # Count minor pieces
    w_minors = count_bits(board.bitboards[Piece.W_BISHOP]) +
               count_bits(board.bitboards[Piece.W_KNIGHT])
    b_minors = count_bits(board.bitboards[Piece.B_BISHOP]) +
               count_bits(board.bitboards[Piece.B_KNIGHT])

    # Only kings
    if w_minors == 0 && b_minors == 0
        return true
    end

    # King + single minor vs king
    if (w_minors == 1 && b_minors == 0) || (w_minors == 0 && b_minors == 1)
        return true
    end

    # King + bishop vs king + bishop (same color squares)
    if w_minors == 1 && b_minors == 1
        # Get bishop squares
        wb_sq = trailing_zeros(board.bitboards[Piece.W_BISHOP])
        bb_sq = trailing_zeros(board.bitboards[Piece.B_BISHOP])
        # Check square color: light=0, dark=1
        if (wb_sq % 8 + wb_sq ÷ 8) % 2 == (bb_sq % 8 + bb_sq ÷ 8) % 2
            return true
        end
    end

    return false
end

"""
    game_status(board::Board) -> Symbol

Return the current game status (checkmate, stalemate, draw, timeout, or ongoing).

- `game`: Game struct
Returns: Symbol — one of
  - `:checkmate_white`
  - `:checkmate_black`
  - `:stalemate`
  - `:draw_threefold`
  - `:draw_fiftymove`
  - `:draw_insufficient_material`
  - `:timeout_white`
  - `:timeout_black`
  - `:ongoing`
"""
function game_status(board::Board)
    if !has_legal_move(board)
        if in_check(board, board.side_to_move)
            return (board.side_to_move == WHITE) ? :checkmate_black : :checkmate_white
        else
            return :stalemate
        end
    end

    if is_insufficient_material(board)
        return :draw_insufficient_material
    elseif is_threefold_repetition(board)
        return :draw_threefold
    elseif is_fifty_move_rule(board)
        return :draw_fiftymove
    end

    return :ongoing
end

"""
    game_status(game::Game) -> Symbol

Return the current game status (checkmate, stalemate, draw, timeout, or ongoing).

- `game`: Game struct
Returns: Symbol — one of
  - `:checkmate_white`
  - `:checkmate_black`
  - `:stalemate`
  - `:draw_threefold`
  - `:draw_fiftymove`
  - `:draw_insufficient_material`
  - `:timeout_white`
  - `:timeout_black`
  - `:ongoing`
"""
function game_status(game::Game)
    status = game_status(game.board)

    # If the position is still ongoing, check time conditions
    if status == :ongoing
        if game.white_time <= 0
            return :timeout_white  # White flagged
        elseif game.black_time <= 0
            return :timeout_black  # Black flagged
        end
    end

    return status
end
