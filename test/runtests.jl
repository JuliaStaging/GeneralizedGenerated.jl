using GG
using Test
using BenchmarkTools

# From Chris Rackauckas: https://github.com/JuliaLang/julia/pull/32737
@inline @generated function _invokefrozen(f, ::Type{rt}, args...) where rt
    tupargs = Expr(:tuple,(a==Nothing ? Int : a for a in args)...)
    quote
        _f = $(Expr(:cfunction, Base.CFunction, :f, rt, :((Core.svec)($((a==Nothing ? Int : a for a in args)...))), :(:ccall)))
        return ccall(_f.ptr,rt,$tupargs,$((:(getindex(args,$i) === nothing ? 0 : getindex(args,$i)) for i in 1:length(args))...))
    end
end
# @cscherrer's modification of `invokelatest` does better on kwargs
export invokefrozen
@inline function invokefrozen(f, rt, args...; kwargs...)
    g(kwargs, args...) = f(args...; kwargs...)
    kwargs = (;kwargs...)
    _invokefrozen(g, rt, (;kwargs...), args...)
end
@inline function invokefrozen(f, rt, args...)
    _invokefrozen(f, rt, args...)
end

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

    g_f = mk_function(:(x, y), :(), :(x + y))
    @test g_f(10, 2) == 12

    eval(:(hpre(x,y) = x+y))

    static_f(x,y) = x+y

    g_f(1, 2)
    hpre(1, 2)
    static_f(1, 2)

    @btime $g_f(1, 2)
    @btime $hpre(1, 2)
    @btime $static_f(1, 2)



end
