using Documenter, GG

makedocs(;
    modules=[GG],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/thautwarm/GG.jl/blob/{commit}{path}#L{line}",
    sitename="GG.jl",
    authors="thautwarm",
    assets=String[],
)

deploydocs(;
    repo="github.com/thautwarm/GG.jl",
)
