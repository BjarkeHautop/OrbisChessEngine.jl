module OrbisChessEngine

# === Core types and basic utilities ===
include("chess_core/types.jl") # Board struct and related
include("chess_core/move.jl") # Move struct and related
include("chess_core/bit_helpers.jl")  # Bitboard manipulation
include("chess_core/zobrist.jl")      # Zobrist hashing
include("chess_core/fen.jl")          # FEN parsing

# === Board-related helper functions ===
include("chess_core/board_helpers.jl")

# === Game state ===
include("opening_book.jl")  # Polyglot opening book support
include("chess_core/game.jl") # Game struct, time controls, game_end logic

# === Move generation ===
include("chess_core/move_generation/magic_numbers.jl")
include("chess_core/move_generation/magic_bishop.jl")
include("chess_core/move_generation/sliding_moves.jl")
include("chess_core/move_generation/pawn_moves.jl")
include("chess_core/move_generation/knight_moves.jl")
include("chess_core/move_generation/king_moves.jl")
include("chess_core/move_generation/null_move.jl")
include("chess_core/move_generation/legal_moves.jl")

# === Move execution ===
include("chess_core/move_execution/make_move.jl")
include("chess_core/move_execution/undo_move.jl")

include("piece_square_tables.jl")
include("evaluate.jl")
include("perft.jl")  # Perft testing
include("searchj.jl")
include("api.jl")    # User-facing API functions
include("ui.jl")    # Board display
include("uci/uci_helpers.jl")  # UCI protocol handling helpers
include("uci/uci.jl")  # UCI protocol handling

# Core types
export Board, UndoInfo, Move, Game, SearchResult

# Piece constants & colors
export Piece, WHITE, BLACK

# Move generation & game state
export generate_legal_moves, generate_legal_moves!
export make_move!, make_move, undo_move!, undo_move, engine_move!, engine_move
export in_check, game_status

# Evaluation & search
export evaluate, search, search_with_time

# Perft & testing
export perft, perft_fast, perft_bishop_magic

# Opening book
export PolyglotBook, load_polyglot_book
export book_move, polyglot_hash, KOMODO_OPENING_BOOK

# ui
export plot_board

end
