using GG
using Test

@testset "GG.jl" begin
    # Write your own tests here.

    quote
        a = 1
        [a](b,) -> a + b
    end |>  closure_conv_static |> println
    @generated function f(x)
        quote
            [x](a) ->  x + a
        end |> gg
    end
    @test f(1)(2) == 3

    mk_function(args, kwargs, body) =
    let Args   = args |> expr2typelevel,
        Kwargs = kwargs |> expr2typelevel,
        Body   = body |> expr2typelevel
        RuntimeFn{Args, Kwargs, Body}()
    end

    g = mk_function(:(x, y), :(), :(x + y))
    @test g(10, 2) == 12

end
