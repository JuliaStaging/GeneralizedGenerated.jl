# GG

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://thautwarm.github.io/GG.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://thautwarm.github.io/GG.jl/dev)
[![Build Status](https://travis-ci.com/thautwarm/GG.jl.svg?branch=master)](https://travis-ci.com/thautwarm/GG.jl)

GG enables the generalised generated functions. More concretely,
**supports defining closures in generated functions**.

Besides, some utility stuffs relevant to GG's implementation are exported,
which **allows you to keep `eval` and `invokelastest`** away from Julia
metaprogramming.


## Support Closures in Generated Functions

```julia
using GG
@generated function f(x)
    quote
        y = x
        [x](a) -> x + a
    end |> gg
end

f(1)(2) # => 3
```

P.S: **We need help about the implementation for scoping analysis to avoid the use of explicit capturing like `[x](a) -> x + a`**.


## No `eval`/`invokelatest`!

```julia
# do something almost equivalent to `eval`
# without introducing the world age problem!
using GG

mk_function(args, kwargs, body) =
    let Args   = args |> expr2typelevel,
        Kwargs = kwargs |> expr2typelevel,
        Body   = body |> expr2typelevel
        RuntimeFn{Args, Kwargs, Body}()
    end

f = mk_function(:(x, y), :(), :(x + y))
f(1, 2)
```