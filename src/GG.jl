module GG
using MLStyle
using JuliaVariables
using NameResolution
using CanonicalTraits
using DataStructures
List = LinkedList

export gg, expr2typelevel, interpret
export RuntimeFn, mk_function
export to_type, to_typelist, types_to_typelist

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
