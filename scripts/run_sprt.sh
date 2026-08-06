#!/usr/bin/env bash
set -euo pipefail

REPO=/home/bjarke/GitHub/OrbisChessEngine.jl # edit if needed

OLD_DIR=/tmp/orbis-old
NEW_DIR=/tmp/orbis-new

OLD_COMMIT=d992bcc # edit
NEW_COMMIT=b5aede8 # edit

PGN=/tmp/orbis-tt-sprt.pgn

cleanup() {
    git -C "$REPO" worktree remove --force "$OLD_DIR" 2>/dev/null || true
    git -C "$REPO" worktree remove --force "$NEW_DIR" 2>/dev/null || true
}

setup_worktree() {
    local dir=$1
    local commit=$2

    git -C "$REPO" worktree add "$dir" "$commit"
    julia --project="$dir" -e 'using Pkg; Pkg.instantiate()'
}

cleanup
trap cleanup EXIT

setup_worktree "$OLD_DIR" "$OLD_COMMIT"
setup_worktree "$NEW_DIR" "$NEW_COMMIT"

rm -f "$PGN"

cutechess-cli \
    -engine cmd=julia arg="--project=$NEW_DIR" arg="$NEW_DIR/bin/orbis_uci.jl" name="new" \
    -engine cmd=julia arg="--project=$OLD_DIR" arg="$OLD_DIR/bin/orbis_uci.jl" name="old" \
    -each proto=uci st=1 timemargin=500 \
    -rounds 200 -repeat -concurrency 5 \
    -sprt elo0=0 elo1=10 alpha=0.05 beta=0.05 \
    -pgnout "$PGN"
