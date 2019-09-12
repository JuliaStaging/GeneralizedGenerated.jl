# GeneralizedGenerated

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://thautwarm.github.io/GeneralizedGenerated.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://thautwarm.github.io/GeneralizedGenerated.jl/dev)
[![Build Status](https://travis-ci.com/thautwarm/GeneralizedGenerated.jl.svg?branch=master)](https://travis-ci.com/thautwarm/GeneralizedGenerated.jl)

GeneralizedGenerated enables the generalised generated functions. More concretely,
**supports defining closures in generated functions**.

Besides, some utility stuffs relevant to GeneralizedGenerated's implementation are exported,
which **allows you to keep `eval` and `invokelastest`** away from Julia
metaprogramming.


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