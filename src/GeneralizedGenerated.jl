module GeneralizedGenerated
using MLStyle
using JuliaVariables
using NameResolution
using CanonicalTraits
using DataStructures
List = LinkedList

export gg, @gg, top_level_closure_conv, expr2typelevel, interpret
export RuntimeFn, mk_function
export to_type, to_typelist, types_to_typelist, from_type, runtime_eval

include("utils.jl")
include("typeable.jl")
include("runtime_funcs.jl")
include("closure.jl")
include("closure_conv.jl")


function mk_function(ex)
    mk_function(@__MODULE__, ex)
end

function mk_function(mod::Module, ex)
    ex = macroexpand(mod, ex)
    fn = top_level_closure_conv(mod, solve(ex))
    if !(fn isa RuntimeFn)
        error("Expect a function expression")
    end
    fn
end

function mk_function(mod::Module, args, kwargs, body)
    mk_function(mod, Expr(:function, :($(args...), ; $(kwargs...), ), body))
end

function mk_function(args, kwargs, body)
    mk_function(@__MODULE__, args, kwargs, body)
end

function runtime_eval(mod::Module, ex)
    fn_ast = :(function () $ex end)
    mk_function(mod, fn_ast)()
end

function runtime_eval(ex)
    runtime_eval(@__MODULE__, ex)
end

end # module
