module NGG
export to_type, from_type, show_repr, TypeLevel, TVal, TApp, TCons, TNil
export RuntimeFn, Unset, Argument, make_function, rmlines
using MLStyle
using CanonicalTraits
using DataStructures
List = LinkedList

rmlines(ex::Expr) = begin
    hd = ex.head
    tl = map(rmlines, filter(!islinenumbernode, ex.args))
    Expr(hd, tl...)
end
rmlines(@nospecialize(a)) = a
islinenumbernode(@nospecialize(x)) = x isa LineNumberNode

include("typeable.jl")
include("runtime_fns.jl")


"""
julia> using .NGG
julia> make_function(
           :f, #fname
           [
               Argument(:a, nothing, Unset()),
               Argument(:b, nothing, Unset())
           ],  # args
           Argument[], # kwargs
           :(a + b) #expression
       )
f = (a, b;) -> a + b

julia> ans(1, 2)
3
"""
function make_function(
    name::Symbol,
    args::Vector{Argument},
    kwargs::Vector{Argument},
    @nospecialize(ex)
)
    Args = to_type(list(args...))
    Kwargs = to_type(list(kwargs...))
    Ex = to_type(ex)
    RuntimeFn{Args, Kwargs, Ex, name}()
end


end
