# Main function that uses uci_helpers.jl

"""
    run_uci()

Run the UCI (Universal Chess Interface) command loop, reading commands from
`stdin` and writing responses to `stdout` until a `"quit"` command is
received or `stdin` is closed.

See <https://www.wbec-ridderkerk.nl/html/UCIProtocol.html> for the protocol
specification. Only a subset is implemented: `go` honors `depth`, `movetime`,
and `wtime`/`btime` (+ increment) time control; `go infinite` and `stop` do
not interrupt an in-progress search (search runs synchronously to
completion), since that would require restructuring the search to run
cancellably in the background.

# Example

Launch as a UCI engine process, e.g. for use with a UCI-speaking GUI or
`cutechess-cli`:

```
julia --project=. bin/orbis_uci.jl
```
"""
function run_uci()
    board = Board()

    while !eof(stdin)
        cmd = String(strip(readline(stdin)))
        isempty(cmd) && continue
        head = split(cmd)[1]

        if head == "uci"
            handle_uci_command()
        elseif head == "isready"
            handle_isready()
        elseif head == "ucinewgame"
            board = Board()
            tt_clear!()
        elseif head == "position"
            board = handle_position(cmd)
        elseif head == "go"
            handle_go(cmd, board)
        elseif head == "stop"
            handle_stop()
        elseif head == "ponderhit"
            handle_ponderhit()
        elseif head == "setoption"
            handle_setoption()
        elseif head == "register"
            handle_register()
        elseif head == "debug"
            handle_debug()
        elseif head == "quit"
            break
        end
        # stdout is block-buffered (not line-buffered) when piped to another
        # process, so a GUI/cutechess-cli parent would hang waiting for a
        # response without an explicit flush after every command.
        flush(stdout)
    end

    return nothing
end
