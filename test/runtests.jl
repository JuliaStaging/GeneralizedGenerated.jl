using GeneralizedGenerated
using JuliaVariables
using Test
using BenchmarkTools
using DataStructures


rmlines(ex::Expr) = begin
    hd = ex.head
    tl = map(rmlines, filter(!islinenumbernode, ex.args))
    Expr(hd, tl...)
end
rmlines(a) = a
islinenumbernode(x) = x isa LineNumberNode

@testset "no kwargs" begin

@gg function f1(a)
    quote
        x -> a + x
    end
end

@test f1(1)(2) == 3

@gg function f2(a)
    quote
        x -> begin
            a += 2
            x + a
        end
    end
end

@test f2(1)(2) == 5


@gg function f3(a)
    quote
        k = 20
        x -> begin
            a += 2
            x + a + k
        end
    end
end

@test f3(1)(2) == 25

end


@testset "kwargs" begin

@gg function f4(a)
    quote
        function z(x, k=1)
            x + 20 + a + k
        end
    end
end

@test f4(10)(2) == 33
end

@testset "namedtuple" begin

@gg function f5(a)
    quote
        function z(x, k=1)
            (x=x, k=k, q=a)
        end
    end
end

@test f5(10)(2) == (x=2, k=1, q=10)
end


@testset "mk funcs" begin

f_ = mk_function(:((x, y) -> x + y))
@test f_(1, 2) == 3

f_ = mk_function(:(function (x, y) x + y end))
@test f_(1, 2) == 3


end

@testset "type encoding more datatypes" begin

@gg function f5(a)
    tp = (1, 2, 3)
    quote
        function z(x, k=$tp)
            (x=x, k=k, q=a)
        end
    end
end

@test f5(10)(2) == (x=2, k=(1, 2, 3), q=10)


@gg function f5(a)
    tp = (a1=1, a2=2, a3=3)
    quote
        function z(x, k=$tp)
            (x=x, k=k, q=a)
        end
    end
end

@test f5(10)(2) == (x=2, k=(a1=1, a2=2, a3=3), q=10)


@gg function f5(a)
    tp = "233"
    quote
        function z(x, k=$tp)
            (x=x, k=k, q=a)
        end
    end
end

@test f5(10)(2) == (x=2, k="233", q=10)


@gg function f5(a)
    tp = list(1, 2, 3)
    quote
        function z(x; k=$tp)
            (x=x, k=k, q=a)
        end
    end
end

@test f5(10)(2) == (x=2, k=list(1, 2, 3), q=10)
@test f5(10)(2; k=10) == (x=2, k=10, q=10)

end

a = to_type(:(1 + 2))
@test :(1 + 2) == from_type(a)
@test string(a) == string(:(1 + 2))


@test runtime_eval(1) == 1
@test mk_function(:(
    x -> x + 1
))(2) == 3

@test_throws Any mk_function(quote
    x -> x + 1
end)


@test runtime_eval(quote
    x -> x + 1
end)(1) == 2

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

# @testset "GeneralizedGenerated.jl" begin
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
