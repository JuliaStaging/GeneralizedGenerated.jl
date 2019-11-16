using JuliaVariables
using MLStyle
include("ngg/ngg.jl")
include("lens.jl")
include("closure.jl")
using .NGG
include("func_arg_decs.jl")

function closure_conv(top::Module, ex::Any)
    function conv(ex::Expr)
        @when Expr(:scoped, scope, inner) = ex begin
            block = Any[]
            for var in scope.bounds
                if var.is_mutable && var.is_shared
                    name = var.name
                    if var.name in scope.bound_inits
                        push!(block, :($name = Core.Box($name)))
                    else
                        push!(block, :($name = Core.Box()))
                    end
                end
            end
            push!(block, conv(inner))
            Expr(:block, block...)
        @when Expr(:function, head, inner&&Expr(:scoped, scope, _)) = ex
            freenames = Symbol[f.name for f in scope.freevars]
            head = conv(head)
            fh = func_header(head)
            fh = @with fh.args = FuncArg[map(func_arg, freenames)..., fh.args...]

            if fh.fresh !== unset || fh.ret !== unset
                error("GG doesn't support type parameters or return type annotations.")
            end

            args = of_args(fh.args)
            kwargs = of_args(fh.kwargs)
            inner = conv(inner)
            name = fh.name === unset ? Symbol(:function) : fh.name
            fn = make_function(Symbol(name), args, kwargs, inner)
            if isempty(freenames)
                fn
            else
                closure_vars = Expr(:tuple, freenames...)
                quote
                    let freevars = $closure_vars
                        $Closure{$fn, Base.typeof(freevars)}(freevars)
                    end
                end
            end
        @when Expr(hd, args...) = ex
            Expr(hd, map(conv, args)...)
        end
    end

    function conv(s::Var)
        name = s.name
        s.is_global && return :($top.$name)
        s.is_mutable && s.is_shared && return begin
            :($name.contents)
        end
        name
    end
    conv(s) = s

    ex = solve(ex)
    conv(ex.args[2])
end

function gg(compmod::Module, runmod::Module, source::Union{Nothing, LineNumberNode}, ex)
    (head, body) = @match ex begin
        Expr(:(=), head, body) => (head, body)
        Expr(:function, head, body) => (head, body)
        Expr(:->, head, body) => (head, body)
        _ => error("Malformed generated function at $source.")
    end
    fh = func_header(head)
    locals = Any[]
    if fh.args !== unset
        for arg in fh.args
            push!(locals, arg.name)
        end
    end
    if fh.kwargs !== unset
        for arg in fh.kwargs
            push!(locals, arg.name)
        end
    end
    if fh.fresh !== unset
        for name in map(extract_tvar, fh.fresh)
            push!(locals, name)
        end
    end
    pseudo_head = fh.name !== unset ? Expr(:call, fh.name, locals...) :
        Expr(:tuple, locals...)

    genbody = quote
        let ast = Base.macroexpand($compmod, $body),
            fake_ast = $solve_from_local(Base.Expr(:function, $pseudo_head, ast))
            $closure_conv($runmod, fake_ast.args[2].args[2])
        end
    end

    generator = Expr(:function, head, genbody)
    Expr(:macrocall, Symbol("@generated"), source, generator)
end

macro gg(ex, modname)
    ex = gg(__module__, modname, __source__, ex)
    esc(ex)
end

macro gg(ex)
    ex = gg(__module__, __module__, __source__, ex)
    esc(ex)
end

fn = closure_conv(Main, :(function f(x)
    function ()
        x + 2
    end
end))


@gg function gn(x)
    quote
        function ()
            x + 2
        end
    end
end

println(fn(1)())
println(gn(1)())