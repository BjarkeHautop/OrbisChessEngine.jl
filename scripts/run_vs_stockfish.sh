#!/usr/bin/env bash
set -euo pipefail

REPO=/home/bjarke/GitHub/OrbisChessEngine.jl # edit if needed

STOCKFISH_ELO=2000 # edit

PGN=/tmp/orbis-vs-stockfish.pgn

rm -f "$PGN"

cutechess-cli \
    -engine cmd=julia arg="--project=$REPO" arg="$REPO/bin/orbis_uci.jl" name="orbis" \
    -engine cmd=stockfish name="stockfish-$STOCKFISH_ELO" option.UCI_LimitStrength=true option.UCI_Elo="$STOCKFISH_ELO" \
    -each proto=uci st=1 timemargin=500 \
    -rounds 40 -repeat -concurrency 5 \
    -pgnout "$PGN"
