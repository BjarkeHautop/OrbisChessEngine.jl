using OrbisChessEngine
using Documenter

DocMeta.setdocmeta!(
    OrbisChessEngine, :DocTestSetup, :(using OrbisChessEngine); recursive = true)

const numbered_pages = [file
                        for file in readdir(joinpath(@__DIR__, "src"))
                        if
                        file != "index.md" && splitext(file)[2] == ".md"]

makedocs(;
    modules = [OrbisChessEngine],
    authors = "Bjarke Hautop Kristensen <bjarke.hautop@gmail.com> and contributors",
    repo = "https://github.com/BjarkeHautop/OrbisChessEngine.jl/blob/{commit}{path}#{line}",
    sitename = "OrbisChessEngine.jl",
    format = Documenter.HTML(;
        canonical = "https://BjarkeHautop.github.io/OrbisChessEngine.jl",
        repolink = "https://github.com/BjarkeHautop/OrbisChessEngine.jl",
        example_size_threshold = nothing,
        size_threshold_ignore = ["05-quick-guide.md"]),
    pages = ["index.md"; numbered_pages]
)

deploydocs(; repo = "github.com/BjarkeHautop/OrbisChessEngine.jl")
