# This file implements closure conversions.
using Parameters

function mk_closure_static(expr, toplevel::Vector{Expr})
    rec(expr) = mk_closure_static(expr, toplevel)
    @match expr begin
        # main logic
        Expr(:scope, _, frees, _, inner_expr) =>
            let closure_arg = :($(frees...), ),
                name = "",
                args   = Symbol[]

                @match inner_expr begin
                    Expr(:function, :($name($(args...), )), body)            ||
                    # (a, b, c, ...) -> body / function (a, b, c, ...) body end
                    Expr(:-> || :function, Expr(:tuple, args...), body)      ||
                    # a -> body
                    Expr(:-> || :function, a::Symbol, body) && Do(args=[a])  =>
                        let glob_name   = gensym(name),
                            (args, kwargs) = split_args_kwargs(args),
                            body   = rec(body)

                            (fn_expr, ret) = if isempty(frees)
                                fn_expr = Expr(
                                    :function,
                                    :($glob_name($(args...); $(kwargs...))),
                                    body
                                )
                                (fn_expr, :glob_name)
                            else
                                fn_expr = Expr(
                                    :function,
                                    :($glob_name($closure_arg, $(args...); $(kwargs...))),
                                    body
                                )
                                ret = :(let frees = $closure_arg
                                    $Closure{$glob_name, typeof(frees)}(frees)
                                end)
                                (fn_expr, ret)
                            end

                            push!(toplevel, fn_expr)

                            if name == "" # anonymous function
                                ret
                            else
                                :($name = $glob_name)
                            end
                        end

                    _ => throw("unsupported closures")
                end
            end
        Expr(hd, tl...) => Expr(hd, map(rec, tl)...)
        a               => a
    end
end


function closure_conv_static(block)
    defs = Expr[]
    push!(defs, mk_closure_static(scoping(block), defs))
    Expr(:block, defs...)
end


macro closure_conv_static(block)
    closure_conv_static(block) |> esc
end


struct RuntimeFn{Args, Kwargs, Body} end

@generated function (::RuntimeFn{Args, Kwargs, Body})(args...; kwargs...) where {Args, Kwargs, Body}
    args_ = interpret(Args)
    kwargs_ = interpret(Kwargs)
    body = interpret(Body)
    quote
        $args_ = args
        @unpack $kwargs_ = kwargs
        $body
    end
end

function closure_conv_staged(expr)
    rec = closure_conv_staged
    @match expr begin
        # main logic
        Expr(:scope, _, frees, _, inner_expr) =>
            let closure_arg = Expr(:tuple, frees...),
                name = "",
                args   = Symbol[]
                @match inner_expr begin
                    Expr(:function, :($name($(args...), )), body)            ||
                    # (a, b, c, ...) -> body / function (a, b, c, ...) body end
                    Expr(:-> || :function, Expr(:tuple, args...), body)      ||
                    # a -> body
                    Expr(:-> || :function, a::Symbol, body) && Do(args=[a])  =>
                        let (args, kwargs) = split_args_kwargs(args),
                            body   = rec(body),
                            kwargs = map(x -> x.args[1], kwargs)
                            Kwargs = expr2typelevel(Expr(:tuple, kwargs...))
                            Body   = expr2typelevel(body)
                            if isempty(frees)
                                Args = expr2typelevel(Expr(:tuple, args...))
                                RuntimeFn{Args, Kwargs, Body}()
                            else
                                Args = expr2typelevel(Expr(:tuple, closure_arg, args...))
                                non_closure_fn = RuntimeFn{Args, Kwargs, Body}()
                                ret = :(let frees = $closure_arg
                                    $Closure{$non_closure_fn, typeof(frees)}(frees)
                                end)
                                if name == "" # anonymous function
                                    ret
                                else
                                    :($name = $ret)
                                end
                            end
                        end
                    _ => throw("unsupported closures")
                end
            end
        Expr(hd, tl...) => Expr(hd, map(rec, tl)...)
        a               => a
    end
end

function gg(x)
    closure_conv_staged(scoping(x))
end