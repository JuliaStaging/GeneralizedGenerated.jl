abstract type TypeLevel{T} end
struct TVal{T, Val} <: TypeLevel{T} end
struct TApp{Ret, Fn, Args} <: TypeLevel{Ret} end
struct TCons{T, Hd, Tl} <: TypeLevel{Cons{T}} end
struct TNil{T} <: TypeLevel{Nil{T}} end

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

Base.show(io::IO, t::Type{<:TypeLevel}) = show_t(io, t)
show_t(io::IO, @nospecialize(t)) = begin
    @match t begin
        ::Type{TypeLevel{L}} where L => print(io, "TypeLevel{",  L, "}")
        ::Type{TypeLevel} => print(io, "TypeLevel")
         _ => begin
            print(io, "TypeEncoding(")
            show_repr(io, t)
            print(io, ")")
         end
    end
end


@trait Typeable{T} begin
    to_type    :: T => Type{<:TypeLevel{T}}
    to_type(@nospecialize(x)) = TVal{T, x}
    from_type  :: Type{<:TypeLevel{T}} => T
    from_type(@nospecialize(t)) = interpret(t)

    show_repr :: [IO, Type{<:TypeLevel{T}}] => Nothing
    show_repr(io::IO, @nospecialize(t)) = begin
        print(io, from_type(t))
    end
end

to_typelist(@nospecialize(many)) =
    let T = eltype(many)
        foldr(many, init=TNil{T}) do each, prev
            TCons{T, to_type(each), prev}
        end
    end

types_to_typelist(@nospecialize(many)) =
    let T = eltype(many)
        foldr(many, init=TNil{T}) do each, prev
            TCons{T, each, prev}
        end
    end

@implement Typeable{L} where {T, L <: List{T}} begin
    to_type(@nospecialize(x)) = to_typelist(T[x...])
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
    function to_type(@nospecialize(ln))
        f = LineNumberNode
        args = Any[ln.line, ln.file] |> to_typelist
        TApp{LineNumberNode, f, args}
    end
end

@implement Typeable{QuoteNode} begin
    function to_type(@nospecialize(x))
        f = QuoteNode
        args = [x.value] |> to_typelist
        TApp{QuoteNode, f, args}
    end
end

@implement Typeable{Tp} where Tp <: Tuple  begin
    function to_type(@nospecialize(x))
        args = collect(x) |> to_typelist
        TApp{Tp, tuple, args}
    end
end

const named_tuple_maker(p...) = (;p...)

@implement Typeable{NamedTuple{Ks, Ts}} where {Ks, Ts} begin
    function to_type(@nospecialize(x))
        f = named_tuple_maker
        args = [kv for kv in zip(Ks, values(x))] |> to_typelist
        TApp{NamedTuple{Ks, Ts}, f, args}
    end
end

@implement Typeable{Symbol}
@implement Typeable{T} where T <: Number
@implement Typeable{T} where T <: Type
@implement Typeable{T} where T <: Function
@implement Typeable{Nothing}

@implement Typeable{String} begin
    function to_type(x::String)
        wrapped = Symbol(x) |> to_type
        TVal{String, wrapped}
    end
    function from_type(::Type{TVal{String, V}}) where V
        string(from_type(V))
    end
end

using Base.Threads: lock, unlock, SpinLock
const _modules = Module[]
const _lock = SpinLock()
function module_index(m::Module)
    lock(_lock)
    try
        i = findfirst(==(m), _modules)
        if i === nothing
            # TODO: thread safe
            push!(_modules, m)
            i = length(_modules)
        end
        i
    finally
        unlock(_lock)
    end
end

@implement Typeable{Module} begin
    function to_type(x::Module)
        TVal{Module, module_index(x)}
    end
    function from_type(:: Type{TVal{Module, V}}) where V
        _modules[V]
    end
end

@implement Typeable{GlobalRef} begin
    function to_type(x::GlobalRef)
        TVal{GlobalRef, to_type((x.mod, x.name))}
    end
    function from_type(::Type{TVal{GlobalRef, V}}) where V
        mod, v = from_type(V)
        GlobalRef(mod, v)
    end
end
