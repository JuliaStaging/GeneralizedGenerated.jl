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
        :(:: $ty) => @with func_arg(gensym("_")).type = ty
        :($var :: $ty) => @with func_arg(var).type = ty
        Expr(:kw, var, default) => @with func_arg(var).default = default
        Expr(:(=), var, default) => @with func_arg(var).default = default
        var::Symbol => FuncArg(var, unset, unset)
        Expr(:..., _) => error(
                "GG does not support variadic argument($ex) so far.\n"
                * "Try\n"
                * "  f(x...) = _f(x)\n"
                * "  @gg _f(x) = ...\n"
                * "See more at: https://github.com/JuliaStaging/GeneralizedGenerated.jl/issues/38")
        _ => error("GG does not understand the argument $ex.")
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