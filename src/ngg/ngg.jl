module NGG
export to_type, from_type, show_repr, TypeLevel, TVal, TApp, TCons, TNil
export RuntimeFn, Unset, Argument, mkngg, rmlines
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


function vectolist(x::Vector{T}) where T
    foldr(x, init=nil(T)) do e, last
        Cons{T}(e, last)
    end
end

"""
julia> using .NGG
julia> mkngg(
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
function mkngg(
    name::Symbol,
    args::Vector{Argument},
    kwargs::Vector{Argument},
    @nospecialize(ex)
)
    arglist = vectolist(args)
    Args = to_type(arglist)

    kwarglist = vectolist(kwargs)
    Kwargs = to_type(kwarglist)
    Ex = to_type(ex)
    RuntimeFn{Args, Kwargs, Ex, name}()
end


end
