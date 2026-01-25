using OrbisChessEngine
using Test

#=
Don't add your tests to runtests.jl. Instead, create files named

    test-title-for-my-test.jl

The file will be automatically included inside a `@testset` with title "Title For My Test".
=#
function run_tests(test_aqua::Bool)
    for (root, dirs, files) in walkdir(@__DIR__)
        for file in files
            if isnothing(match(r"^test-.*\.jl$", file))
                continue
            end

            if !test_aqua && file == "test-aqua.jl"
                continue
            end

            title = titlecase(replace(splitext(file[6:end])[1], "-" => " "))
            @testset "$title" begin
                include(file)
            end
        end
    end
end

run_tests(true)
