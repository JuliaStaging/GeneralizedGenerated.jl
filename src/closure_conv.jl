# This file implements closure conversions.

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
                    Expr(hd && if hd in (:->, :function) end, Expr(:tuple, args...), body)      ||
                    # a -> body
                    Expr(hd && if hd in (:->, :function) end, a::Symbol, body) && Do(args=[a])  =>
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

EmptyTupleExprTy = as_type(:())

@generated function (::RuntimeFn{Args, EmptyTupleExprTy, Body})(args...) where {Args, Body}
    args_ = interpret(Args)
    body = interpret(Body)
    quote
        let $args_ = args
            $body
        end
    end
end

struct Unset end

@generated function (::RuntimeFn{Args, Kwargs, Body})(args...; kwargs...) where {Args, Kwargs, Body}
    args_   = interpret(Args) # Expr
    kwargs_ = map(interpret(Kwargs).args) do expr
                    @match expr begin
                        a::Symbol            => (a, Unset())
                        :($(k::Symbol) = $v) => (k, v)
                        e                    =>
                            error("invalid kwargs definition: $(e)")
                    end
             end
    body = interpret(Body)
    function get_kwds(::Type{Base.Iterators.Pairs{A, B, C, NamedTuple{Kwds,D}}}) where {Kwds, A, B, C, D}
        Kwds
    end
    kwds = gensym("kwds")
    feed_in_kwds = get_kwds(kwargs)

    unpack_kwargs = map(kwargs_) do (k, default)
        k in feed_in_kwds && return :($k = $kwds[$(QuoteNode(k))])
        default === Unset() && error("no default value for keyword argument $(k)")
        return :($k = $default)
    end
    assign_block = [
        :($kwds = kwargs),
        :($args_ = args),
        unpack_kwargs...
    ]
    quote
        let $(assign_block...)
            $body
        end
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
                    Expr(hd && if hd in (:->, :function) end, Expr(:tuple, args...), body)      ||
                    # a -> body
                    Expr(hd && if hd in (:->, :function) end, a::Symbol, body) && Do(args=[a])  =>
                        let (args, kwargs) = split_args_kwargs(args),
                            body   = rec(body),
                            kwargs = map(x -> x.args[1], kwargs)
                            Kwargs = expr2typelevel(Expr(:tuple, kwargs...))
                            Body   = expr2typelevel(body)
                            ret = if isempty(frees)
                                Args = expr2typelevel(Expr(:tuple, args...))
                                RuntimeFn{Args, Kwargs, Body}()
                            else
                                Args = expr2typelevel(Expr(:tuple, closure_arg, args...))
                                non_closure_fn = RuntimeFn{Args, Kwargs, Body}()
                                :(let frees = $closure_arg
                                    $Closure{$non_closure_fn, typeof(frees)}(frees)
                                end)
                            end
                            if name == "" # anonymous function
                                ret
                            else
                                :($name = $ret)
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
