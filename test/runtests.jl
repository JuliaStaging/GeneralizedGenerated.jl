using GG
using JuliaVariables
using Test
using BenchmarkTools


rmlines(ex::Expr) = begin
    hd = ex.head
    tl = map(rmlines, filter(!islinenumbernode, ex.args))
    Expr(hd, tl...)
end
rmlines(a) = a
islinenumbernode(x) = x isa LineNumberNode

@testset "no kwargs" begin

@generated function f1(a)
    quote
        z = a
        x -> z + x
    end |> gg
end

@test f1(1)(2) == 3

@generated function f2(a)
    quote
        z = a
        x -> begin
            z += 2
            x + z
        end
    end |> gg
end

@test f2(1)(2) == 5


@generated function f3(a)
    quote
        z = a
        k = 20
        x -> begin
            z += 2
            x + z + k
        end
    end |> gg
end

@test f3(1)(2) == 25

end


@testset "kwargs" begin

@generated function f4(a)
    quote
        q = a
        function z(x, k=1)
            x + 20 + q + k
        end
    end |> gg
end

@test f4(10)(2) == 33
end

@testset "namedtuple" begin

@generated function f5(a)
    quote
        q = a
        function z(x, k=1)
            (x=x, k=k, q=q)
        end
    end |> gg
end

@test f5(10)(2) == (x=2, k=1, q=10)
end


# # From Chris Rackauckas: https://github.com/JuliaLang/julia/pull/32737
# @inline @generated function _invokefrozen(f, ::Type{rt}, args...) where rt
#     tupargs = Expr(:tuple,(a==Nothing ? Int : a for a in args)...)
#     quote
#         _f = $(Expr(:cfunction, Base.CFunction, :f, rt, :((Core.svec)($((a==Nothing ? Int : a for a in args)...))), :(:ccall)))
#         return ccall(_f.ptr,rt,$tupargs,$((:(getindex(args,$i) === nothing ? 0 : getindex(args,$i)) for i in 1:length(args))...))
#     end
# end
# # @cscherrer's modification of `invokelatest` does better on kwargs
# export invokefrozen
# @inline function invokefrozen(f, rt, args...; kwargs...)
#     g(kwargs, args...) = f(args...; kwargs...)
#     kwargs = (;kwargs...)
#     _invokefrozen(g, rt, (;kwargs...), args...)
# end
# @inline function invokefrozen(f, rt, args...)
#     _invokefrozen(f, rt, args...)
# end

# @testset "GG.jl" begin
#     # Write your own tests here.

#     quote
#         a = 1
#         [a](b,) -> a + b
#     end |>  closure_conv_static |> println
#     @generated function f(x)
#         quote
#             [x](a) ->  x + a
#         end |> gg
#     end
#     @test f(1)(2) == 3


#     g_f = mk_function([:x, :y], [], :(x + y))
#     @test g_f(10, 2) == 12

#     eval(:(hpre(x,y) = x+y))

#     static_f(x,y) = x+y

#     g_f(1, 2)
#     hpre(1, 2)
#     static_f(1, 2)

#     @info :GG_approach
#     @btime $g_f(1, 2)

#     @info :eval
#     @btime $hpre(1, 2)

#     @btime $static_f(1, 2)



# end
