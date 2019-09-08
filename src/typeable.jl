abstract type TypeLevel{T} end
struct TVal{T, Val} <: TypeLevel{T} end
struct TApp{Ret, Fn, Args} <: TypeLevel{Ret} end
struct TCons{T, Hd, Tl} <: TypeLevel{List{T}} end
struct TNil{T} <: TypeLevel{List{T}} end

function interpret(t::Type{TNil{T}}) where T
    nil(T)
end

function interpret(t::Type{TVal{T, V}}) where {T, V}
    V
end

function interpret(t::Type{TCons{T, Hd, Tl}}) where {T, Hd, Tl}
    tl :: List{T} = from_type(Tl)
    cons(from_type(Hd), tl)
end

function interpret(t::Type{TApp{Ret, Fn, Args}}) where {Fn, Args, Ret}
    args = from_type(Args)
    Fn(args...) :: Ret
end


Base.show(io::IO, t::Type{<:TypeLevel{T}}) where T = print(io, "encode{$T}")
# Base.show(io::IO, t::Type{<:TypeLevel{T}}) where T = show(io, interpret(t))

@trait Typeable{T} begin
    to_type    :: T => Type{<:TypeLevel{T}}
    to_type(x::T) = TVal{T, x}
    from_type  :: Type{<:TypeLevel{T}} => T
    from_type(t::Type{<:TypeLevel{T}}) = interpret(t)
end

to_typelist(many) =
    let T = eltype(many)
        foldr(many, init=TNil{T}) do each, prev
            TCons{T, to_type(each), prev}
        end
    end

types_to_typelist(many) =
    let T = eltype(many)
        foldr(many, init=TNil{T}) do each, prev
            TCons{T, each, prev}
        end
    end

# compat
expr2typelevel = to_typelist

@implement Typeable{L} where {T, L <: List{T}} begin
    to_type(x) = to_typelist(x)
end

@implement Typeable{Expr} begin
    function to_type(x::Expr)
        @when Expr(args...) = x begin
            args = to_typelist(args)
            f  = Expr
            TApp{Expr, f, args}
        @otherwise
            error("impossible")
        end
    end
end

@implement Typeable{LineNumberNode} begin
    function to_type(ln)
        f = LineNumberNode
        args = Any[ln.line, ln.file] |> to_typelist
        TApp{LineNumberNode, f, args}
    end
end

@implement Typeable{QuoteNode} begin
    function to_type(x)
        f = QuoteNode
        args = [x.value] |> to_typelist
        TApp{QuoteNode, f, args}
    end
end

@implement Typeable{Tp} where Tp <: Tuple  begin
    function to_type(x)
        args = collect(x) |> to_typelist
        TApp{Tp, tuple, args}
    end
end

const named_tuple_maker(p...) = (;p...)

@implement Typeable{NamedTuple{Ks, Ts}} where {Ks, Ts} begin
    function to_type(x)
        f = named_tuple_maker
        args = [kv for kv in zip(Ks, values(x))] |> to_typelist
        TApp{NamedTuple{Ks, Ts}, f, args}
    end
end

@implement Typeable{Symbol}
@implement Typeable{T} where T <: Number
@implement Typeable{Type}
@implement Typeable{Nothing}

@implement Typeable{String} begin
    function to_type(x::String)
        wrapped = Symbol(x) |> to_type
        TVal{String, wrapped}
    end
    function from_type(::Type{TVal{String, V}}) where V
        string(V)
    end
end