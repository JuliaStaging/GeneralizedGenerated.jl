# This file implements closure conversions.
struct RuntimeFn{Args, Kwargs, Body} end
struct Unset end


struct Argument
    name    :: Symbol
    type    :: Union{Nothing, Any}
    default :: Union{Unset,  Any}
end

struct Arguments
    args   :: Vector{Argument}
    kwargs :: Vector{Argument}
end

@implement Typeable{Unset}

@implement Typeable{Argument} begin
    to_type(arg) =
        let f = Argument
            args = [arg.name, arg.type, arg.default] |> to_typelist
            TApp{Argument, f, args}
        end
end


# @implement Typeable{Arguments} begin
#     to_type(args) =
#         let f = Arguments
#             args = [
#                 list(args.args...) |> to_typelist,
#                 list(args.kwargs...) |> to_typelist
#             ] |> types_to_typelist
#             TApp{f, args, Arguments}
#         end
# end

function _ass_positional_args!(assign_block::Vector{Expr}, args :: List{Argument}, ninput::Int, pargs :: Symbol)
    i = 1
    for arg in args
        ass = arg.name
        if arg.type !== nothing
            ass = :($ass :: $(arg.type))
        end
        if i > ninput
            arg.default === Unset() && error("Input arguments too few.")
            ass = :($ass = $(arg.default))
        else
            ass = :($ass = $pargs[$i])
        end
        push!(assign_block, ass)
        i += 1
    end
end

@generated function (::RuntimeFn{Args, TNil{Argument}, Body})(pargs...) where {Args, Body}
    args   = interpret(Args)
    ninput = length(pargs)
    assign_block = Expr[]
    body = interpret(Body)
    _ass_positional_args!(assign_block, args, ninput, :pargs)
    quote
        let $(assign_block...)
            $body
        end
    end
end

@generated function (::RuntimeFn{Args, Kwargs, Body})(pargs...; pkwargs...) where {Args, Kwargs, Body}
    args   = interpret(Args)
    kwargs = interpret(Kwargs)
    ninput = length(pargs)
    assign_block = Expr[]
    body = interpret(Body)
    if isempty(kwargs)
        _ass_positional_args!(assign_block, args, ninput, :pargs)
    else
        function get_kwds(::Type{Base.Iterators.Pairs{A, B, C, NamedTuple{Kwds,D}}}) where {Kwds, A, B, C, D}
            Kwds
        end
        kwds = gensym("kwds")
        feed_in_kwds = get_kwds(pkwargs)
        push!(assign_block, :($kwds = pkwargs))
        _ass_positional_args!(assign_block, args, ninput, :pargs)
        for kwarg in kwargs
            ass = k = kwarg.name
            if kwarg.type !== nothing
                ass = :($ass :: $(kwarg.type))
            end
            if k in feed_in_kwds
                ass = :($ass = $kwds[$(QuoteNode(k))])
            else
                default = kwarg.default
                default === Unset() && error("no default value for keyword argument $(k)")
                ass = :($ass = $default)
            end
            push!(assign_block, ass)
        end
    end
    quote
        let $(assign_block...)
            $body
        end
    end
end


function build_argument(arg) :: Argument
    @when Expr(:kw, _...) = arg begin
        arg.head = :(=)
    end
    default = Unset()
    @when :($a = $b) = arg begin
        default = closure_conv(b)
        arg = a
    end
    type = nothing
    @when :($a :: $b) = arg begin
        arg = a
        type = closure_conv(b)
    @when :(:: $b) = arg
        arg = :_
        type = closure_conv(b)
    end

    @when ::ScopedVar = arg begin
        arg = arg.sym

    @when ::Symbol = arg
        nothing
    @otherwise
        error("not supported argument name $arg.")
    end

    Argument(arg, type, default)
end

function build_arguments(args, kwargs)
    Arguments(map(build_argument, args), map(build_argument, kwargs))
end

"""
also canonicalize the arguments
"""
inject_freesyms_as_arg!(freesyms::Vector{Symbol}, call, ref::Ref{Union{Nothing, ScopedVar}}) =
    @when :($f($(args...))) = call begin
        (args, kwargs) = split_args_kwargs(args)
        ref.x = f
        build_arguments([freesyms..., args...], kwargs)

    @when Expr(:tuple, args...) = call
        (args, kwargs) = split_args_kwargs(args)
        build_arguments([freesyms..., args...], kwargs)


    @when f :: Union{Symbol, ScopedVar} = call
        build_arguments([freesyms..., f], [])

    @when :($f :: $t) = call
        error("'annotation' not implemented")
    #     f = inject_freesyms_as_arg!(freesyms, f, ref)
    #     :($f :: $t)

    @when :($f where {$(ts...)}) = call
        error("'where' not implemented")
    #     f = inject_freesyms_as_arg!(freesyms, f, ref)
    #     :($f where {$(ts...)})

    @otherwise
        error("Malformed function signature $call.")

    end

function process_mutable_cells!(argnames :: Vector{Symbol}, bounds::Vector{LocalVar}, body)
    # mutable free variables stored in Core.Box
    stmts = Expr[]
    for bound in bounds
        if bound.is_mutable.x
            sym = bound.sym
            if sym in argnames
                push!(stmts, :($sym = $Core.Box($sym)))
            else
                push!(stmts, :($sym = $Core.Box()))
            end
        end
    end
    Expr(:let, Expr(:block, stmts...), body)
end

function closure_conv(ex::ScopedFunc)
    scope  = ex.scope
    frees  = LocalVar[values(scope.freevars)...]
    bounds = LocalVar[values(scope.bounds)...]
    freesyms = Symbol[x.sym for x in frees]
    @when Expr(hd, sig, body) = ex.func begin
        check_fun_mut = Ref{Union{Nothing, ScopedVar}}(nothing)
        sig = inject_freesyms_as_arg!(freesyms, sig, check_fun_mut)
        argnames = Symbol[[arg.name for arg in sig.args];[arg.name for arg in sig.kwargs]]
        body = process_mutable_cells!(argnames, bounds, closure_conv(body))
        Args = to_typelist(sig.args)
        Kwargs = to_typelist(sig.kwargs)
        fn = RuntimeFn{Args, Kwargs, to_type(body)}()
        if !isempty(freesyms)
            tp = Expr(:tuple, freesyms...)
            fn = :(let _free = $tp; $Closure{$fn, $typeof($tp)}(_free) end)
        end
        if check_fun_mut.x isa LocalVar
            sym = check_fun_mut.x |> closure_conv
            fn = :($sym = $fn)
        end
        fn
    @otherwise
        error("impossible")
    end
end

function closure_conv(ex::ScopedGenerator)
    error("Not implemented")
end

function closure_conv(ex::ScopedVar)
    var = ex.scope[ex.sym]
    var isa GlobalVar && return var
    if var.is_shared.x && var.is_mutable.x
        return :($(var.sym).contents)
    end
    return var.sym
end

function closure_conv(ex)
    @match ex begin
        Expr(hd, args...) => Expr(hd, map(closure_conv, args)...)
        a => a
    end
end

function gg(ex)
    closure_conv(solve_from_local(ex))
end