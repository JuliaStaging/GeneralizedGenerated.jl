module GG
using MLStyle

export closure_conv_static, @closure_conv_static, gg, typelevellist, expr2typelevel, interpret, closure_conv_staged
export RuntimeFn, mk_function

include("typeable.jl")
include("closure.jl")
include("utils.jl")

include("explicit_scope.jl")
include("closure_conv.jl")


mk_function(args, kwargs, body) =
    let Args   = args   |> expr2typelevel,
        Kwargs = kwargs |> expr2typelevel,
        Body   = body   |> expr2typelevel
        RuntimeFn{Args, Kwargs, Body}()
    end

end # module
