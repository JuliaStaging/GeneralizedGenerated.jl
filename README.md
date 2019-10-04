# GeneralizedGenerated

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://thautwarm.github.io/GeneralizedGenerated.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://thautwarm.github.io/GeneralizedGenerated.jl/dev)
[![Build Status](https://travis-ci.com/thautwarm/GeneralizedGenerated.jl.svg?branch=master)](https://travis-ci.com/thautwarm/GeneralizedGenerated.jl)
[![Codecov](https://codecov.io/gh/thautwarm/GeneralizedGenerated.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/thautwarm/GeneralizedGenerated.jl)


GeneralizedGenerated enables the generalised generated functions. More concretely,
**supports defining closures in generated functions**.

Besides, some utility stuffs relevant to GeneralizedGenerated's implementation are exported,
which **allows you to keep `eval` and `invokelastest`** away from Julia
metaprogramming.


## Background: World Age Problem

See an explanation [here](https://discourse.julialang.org/t/world-age-problem-explanation/9714/4?u=thautwarm).

```julia
julia> module WorldAgeProblemRaisedHere!
           do_this!(one_ary_fn_ast::Expr, arg) = begin
               eval(one_ary_fn_ast)(arg)
           end
           res = do_this!(:(x -> x + 1), 2)
           @info res
       end
ERROR: MethodError: no method matching (::getfield(Main.WorldAgeProblemRaisedHere!, Symbol("##1#2")))(::Int64)
The applicable method may be too new: running in world age 26095, while current world is 26096.

julia> module WorldAgeProblemSolvedHere!
           using GeneralizedGenerated
           do_this!(one_ary_fn_ast::Expr, arg) = begin
               runtime_eval(one_ary_fn_ast)(arg)
           end
           res = do_this!(:(x -> x + 1), 2)
           @info res
       end
[ Info: 3
Main.WorldAgeProblemSolvedHere!
```

## Support Closures in Generated Functions

```julia
using GeneralizedGenerated

@gg function f(x)
    quote
        a -> x + a
    end
end

f(1)(2) # => 3

```

P.S: We can figure out a pure Julia way to resolve symbols, thus free variables and
other stuffs can be resolved automatically.

Note there're some restrictions to the closures of generated functions yet:

- Multiple dispatch is not allowed, and `f(x) = ...` is equivalent to `f = x -> ...`.
- Comprehensions for generated functions are not implemented yet.
- Default arguments doesn't work unless they're constants. You can just splice variables into the AST to achieve the same   functionlity. The following code works.

    ```julia
    @gg function f(x)
        k = 10
        quote
            d = k + 10
            function g(x, y=$k)
                x + y + d
            end
        end
    end
    ```

## No `eval`/`invokelatest`!

```julia
# do something almost equivalent to `eval`
# without introducing the world age problem!
using GeneralizedGenerated
f = mk_function(:((x, y) -> x + y))
f(1, 2)
# => 3

f = mk_function([:x, :y]#= args =#, []#= kwargs =#, :(x + y))
f(1, 2)
# => 3


module GoodGame
    xxx = 10
end
# Specify global module
f = mk_function(GoodGame, :(function () xxx end))
f()
# => 10
```

The function created by `mk_function` always has the signature `f(args…; kwargs…) = ...` if you need to use the function in a context where it will be passed multiple arguments, use the following pattern

```julia
f = mk_function(:((x, y) -> x + y))

function F(g, pairs)
  map(pairs) do (x,y)
    g(x,y)
  end
end

pairs = zip(1:10,2:11)
F((x,y)->f(x,y), pairs)
#=
=>
10-element Array{Int64,1}:
  3
  5
  7
  9
 11
 13
 15
 17
 19
 21
=#
```

Tips
==============

Note, `mk_function` just accepts a function-like AST, to eval more kinds of
ASTs, use `runtime_eval`:

```julia
a = 0
runtime_eval(:(a + 1)) == 1 # true

module GoodGameOnceAgain
    a = 2
end
runtime_eval(GoodGameOnceAgain, :(a + 3)) == 5
```
