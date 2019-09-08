# This file implements closure conversions.

function top_level_closure_conv(def_module::Module, ex)

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
        var isa GlobalVar && return :($def_module.$var)
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

    closure_conv(ex)
end

function gg(mod::Module, source::Union{Nothing, LineNumberNode}, ex)
    @when Expr(hd, func_sig, body) = ex begin
        # a fake function to get all arguments of the generated function
        quote_hd = QuoteNode(hd)
        quote_sig = QuoteNode(deepcopy(func_sig))
        body = quote
            let ast = $body,
                fake_ast = $Expr($quote_hd, $quote_sig, ast), # to support generator's arguments as closures
                fn :: $ScopedFunc = $solve(fake_ast)
                generated  = $top_level_closure_conv($mod, fn.func.args[2])
            end
        end
        generator = Expr(hd, func_sig, body)
        Expr(:macrocall, Symbol("@generated"), source, generator)
    @otherwise
        error("Malformed generated function at $source.")
    end
end

macro gg(ex)
    gg(__module__, __source__, ex) |> esc
end
