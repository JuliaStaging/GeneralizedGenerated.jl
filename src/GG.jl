module GG
using MLStyle
using JuliaVariables
using NameResolution

export closure_conv_static, @closure_conv_static, gg, expr2typelevel, interpret, closure_conv_staged
export RuntimeFn, mk_function

export as_type, as_types

include("utils.jl")
include("typeable.jl")
include("closure.jl")
include("closure_conv.jl")


function mk_function(ex)
    fn = gg(ex)
    if !(fn isa RuntimeFn)
        error("Expect a function expression")
    end
    fn
end

function mk_function(args, kwargs, body)
    gg(Expr(:function, :($(args...), ; $(kwargs...), ), body))
end

end # module
