module GeneralizedGenerated
using MLStyle
using JuliaVariables
using NameResolution
using CanonicalTraits
using DataStructures
List = LinkedList

export NGG
export gg, @gg, closure_conv, interpret
export RuntimeFn, mk_function, mkngg
export to_type, to_typelist, types_to_typelist, from_type, runtime_eval
include("closure_conv.jl")


function mk_function(ex)
    mk_function(@__MODULE__, ex)
end

function mk_function(mod::Module, ex)
    ex = macroexpand(mod, ex)
    ex = simplify_ex(ex)
    ex = solve(ex)
    fn = closure_conv(mod, ex)
    if !(fn isa RuntimeFn)
        error("Expect an unnamed function expression. ")
    end
    fn
end

function mk_function(mod::Module, args, kwargs, body)
    mk_function(mod, Expr(:function, :($(args...), ; $(kwargs...), ), body))
end

function mk_function(args, kwargs, body)
    mk_function(Main, args, kwargs, body)
end

function runtime_eval(mod::Module, ex)
    fn_ast = :(function () $ex end)
    mk_function(mod, fn_ast)()
end

function runtime_eval(ex)
    runtime_eval(Main, ex)
end

end # module
