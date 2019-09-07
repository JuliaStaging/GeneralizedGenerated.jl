using CanonicalTraits
abstract type TypeLevel end
struct TLCons{Hd, Tl} <: TypeLevel end
struct TLNil <: TypeLevel end
struct TLVal{Val} <: TypeLevel end
struct TLSExp{Fn, Args} <: TypeLevel end

function interpret(t::Type{TLNil})
    []
end

function interpret(t::Type{TLVal{Val}}) where Val
    Val
end

function interpret(t::Type{TLCons{Hd, Tl}}) where {Hd, Tl}
    tl = interpret(Tl)
    @assert tl isa Vector
    [interpret(Hd), tl...]
end

function interpret(t::Type{TLSExp{Fn, Args}}) where {Fn, Args}
    args = interpret(Args)
    @assert args isa Vector
    interpret(Fn)(args...)
end

Base.show(io::IO, t::Type{<:TypeLevel}) = show(io, interpret(t))

@trait Typeable{T} begin
    as_type  :: T => Type{<:TypeLevel}
end

as_types(many) = foldr(many, init=TLNil) do each, prev
    TLCons{as_type(each), prev}
end

from_types(many) = foldr(many, init=TLNil) do each, prev
    TLCons{each, prev}
end

# compat
expr2typelevel = as_type
# typelevellist  = as_types

@implement Typeable{Expr} begin
    function as_type(x::Expr)
        @when Expr(args...) = x begin
            args = as_types(args)
            f  = TLVal{Expr}
            TLSExp{f, args}
        @otherwise
            error("impossible")
        end
    end
end

@implement Typeable{LineNumberNode} begin
    function as_type(ln)
        f = TLVal{LineNumberNode}
        args = Any[ln.line, ln.file] |> as_types
        TLSExp{f, args}
    end
end

@implement Typeable{QuoteNode} begin
    function as_type(x)
        f = TLVal{QuoteNode}
        args = [x.value] |> as_types
        TLSExp{f, args}
    end
end

@implement Typeable{Tuple} begin
    function as_type(x)
        f = TLVal{Tuple}
        args = collect(x) |> as_types
        TLSExp{f, args}
    end
end

named_tuple_keys(::NamedTuple{K,V}) where {K,V} = K 

named_tuple_maker(p...) = (;p...)

@implement Typeable{NamedTuple} begin
    function as_type(x)
        f = TLVal{NamedTuple}
        args = [k => v for (k,v) in zip(named_tuple_keys(x),values(x))]
        TLSExp{TLVal{named_tuple_maker}, args |> as_types}
    end
end

@implement Typeable{Symbol} begin
    as_type(x) = TLVal{x}
end

@implement Typeable{T} where T <: Number begin
    as_type(x) = TLVal{x}
end

@implement Typeable{Type} begin
    as_type(x) = x
end

# @implement Typeable{Arr} where {T, Arr <: AbstractArray{T, 1}} begin
#     as_type(x) = as_types
# end

const sym_to_string(x::Symbol)::String = string(x)
@implement Typeable{String} begin
    as_type(x) =
        let f = TLVal{sym_to_string}
            args = [Symbol(x)] |> as_types
            TLSExp{f, args}
        end
end

@implement Typeable{Nothing} begin
    as_type(x) = TLVal{nothing}
end
