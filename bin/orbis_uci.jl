# Entry point for running OrbisChessEngine as a UCI engine.
#
# Launch with (from the package root, or pointing --project at it):
#
#   julia --project=. bin/orbis_uci.jl
#
# This is the command to hand to a UCI GUI or `cutechess-cli` (e.g.
# `cutechess-cli -engine cmd=julia arg="--project=. bin/orbis_uci.jl" proto=uci ...`).

using OrbisChessEngine

OrbisChessEngine.run_uci()
