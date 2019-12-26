using GeneralizedGenerated
using JuliaVariables
using Test
using BenchmarkTools
using DataStructures


rmlines = NGG.rmlines

@testset "no kwargs" begin

@gg function f1(a)
    quote
        x -> a + x
    end |> rmlines
end

@test f1(1)(2) == 3

@gg function f2(a)
    quote
        x -> begin
            a += 2
            x + a
        end
    end |> rmlines
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

@testset "runtime eval" begin

a = to_type(:(1 + 2))
@test :(1 + 2) == from_type(a)
@test string(from_type(a)) == string(:(1 + 2))


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

end

@testset "self recursive" begin
    to_test = quote
        g(x, r=0) = x === 0 ? r : begin
            g = g # required for self recur
            g(x-1, r + x)
        end
        g(10)
    end |> runtime_eval

    g(x, r=0) = x === 0 ? r : g(x-1, r + x)
    expected = g(10)
    @test expected == to_test
end

@testset "self recursive" begin
    to_test = quote
        g(x, r=0) = x === 0 ? r : begin
            g = g # required for self recur
            g(x-1, r + x)
        end
        g(10)
    end |> runtime_eval

    g(x, r=0) = x === 0 ? r : g(x-1, r + x)
    expected = g(10)
    @test expected == to_test
end


@testset "support where clauses and return type annotations for @gg" begin
    @gg function foo(x::T) where T
        :(x, T)
    end
    @test foo(1) == (1, Int)
    @gg function bar(x::T) where T
        quote
            g = x + 20
            x = 10
            () -> begin
                x = g
                x
            end
        end
    end
    @test bar(2)() == 2 + 20

    @gg function foobar(x::T, y::A) where {T <: Number, A <: AbstractArray{T}}
        quote
            g = x + 20
            x = 10
            () -> begin
                x = g
                (A, x + y[1])
            end
        end
    end
    @test foobar(2, [3])() == (Vector{Int}, 2 + 20 + 3)
end

@testset "support default arguments" begin
    @gg function h(x, c)
        quote
            d = x + 10
            function g(x, y=c)
                x + y + d
            end
        end
    end
    @test h(1, 2)(3) == 16
end

module S
    run(y) = y + 1
end

struct K
    f1::Function
    f2::Function
end
@testset "specifying evaluation modules" begin
    @gg m function g(m::Module, y) :(run(y)) end
    @test g(S, 1) == 2

    @gg m function h(m, y)
        quote
        c = m.f1(y)
        () -> begin c = m.f2(c) end
        end
    end
    k = K(x -> x + 1, x -> x * 9)
    next = h(k, 1)
    @test next() == 18
    @test next() == 18 * 9
end

@testset "test free variables of let bindings" begin
    @gg function test_free_of_let()
        quote
            let x = 1
                f = () -> begin
                    x * 3
                end
                x = 2
                f
            end
        end
    end
    @test test_free_of_let()() == 6
end

@testset "show something" begin
    f1 = mk_function(:(x -> x + 1))
    f2 = mk_function(:((x :: Int = 2, ) -> x + 1))
    @test f1(1) == 2
    @test f2() == 3
    println(f1)
    println(f2)
end

@testset "omit func argname: #34" begin
   f1 = mk_function(:( (:: Int) -> 0 ))
   @test f1(1) == 0
   @test_throws MethodError f1("")
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
