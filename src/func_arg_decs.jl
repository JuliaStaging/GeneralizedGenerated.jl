unset = Unset()

struct FuncArg
    name
    type
    default
end

struct FuncHeader
    name  :: Any
    args  :: Any
    kwargs :: Any
    ret   :: Any
    fresh :: Any
end

FuncHeader() = FuncHeader(unset, unset, unset, unset, unset)

is_func_header(a::FuncHeader) = a.args != unset

function func_arg(@nospecialize(ex))::FuncArg
    @match ex begin
        :($var :: $ty) => @with func_arg(var).type = ty
        Expr(:kw, var, default) => @with func_arg(var).default = default
        var => FuncArg(var, unset, unset)
    end
end

function func_header(@nospecialize(ex))::FuncHeader
    @match ex begin
        :($hd::$ret) => @with func_header(hd).ret = ret

        :($f($(args...); $(kwargs...))) =>
            begin inter = @with func_header(f).args = map(func_arg, args)
                  @with inter.kwargs = map(func_arg, kwargs)
            end
        :($f($(args...))) => @with func_header(f).args = map(func_arg, args)

        :($f where {$(args...)}) => @with func_header(f).fresh = args

        Expr(:tuple, Expr(:parameters, kwargs...), args...) =>
            begin inter = @with FuncHeader().args = map(func_arg, args)
                  @with inter.kwargs = map(func_arg, kwargs)
            end
        Expr(:tuple, args...) => @with FuncHeader().args = map(func_arg, args)

        f => @with FuncHeader().name = f
    end
end

function to_exp(fh::FuncHeader)
    args = Any[]
    flag = if fh.name !== unset
        push!(args, fh.name)
        :call
    else
        :tuple
    end
    if fh.kwargs !== unset
        push!(args, Expr(:parameters, map(to_exp, fh.kwargs)...))
    end
    if fh.args !== unset
        append!(args, map(to_exp, fh.args))
    end
    exp = Expr(flag, args...)
    exp = fh.ret === unset ? exp : Expr(:(::), exp, fh.ret)
    exp = fh.fresh === unset ? exp : Expr(:where, exp, fh.fresh...)
    exp
end

function to_exp(fa::FuncArg)
    base =
        fa.name == unset ? :(:: $(fa.type)) :
        fa.type != unset ? :($(fa.name) :: $(fa.type)) : fa.name
    base = fa.default === unset ? base : Expr(:kw, base, fa.default)
    base
end

function of_args(::Unset)
    Argument[]
end

function of_args(args::AbstractArray{FuncArg})
    ret = Argument[]
    for (i, each) in enumerate(args)
        name = each.name === unset ? gensym("_$i") : each.name
        type = each.type === unset ? nothing : each.type
        arg = Argument(name, type, each.default)
        push!(ret, arg)
    end
    ret
end

extract_tvar(var :: Union{Symbol, Expr})::Symbol =
    @match var begin
        :($a <: $_) => a
        :($a >: $_) => a
        :($_ >: $a >: $_) => a
        :($_ <: $a <: $_) => a
        a::Symbol         => a
    end