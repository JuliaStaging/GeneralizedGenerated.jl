function split_args_kwargs(args)
    @match args begin
        [Expr(:parameters, kwargs...), args...] => (args, kwargs)
        _ => (args, [])
    end
end

rmlines(ex::Expr) = begin
    hd = ex.head
    tl = map(rmlines, filter(!islinenumbernode, ex.args))
    Expr(hd, tl...)
end

rmlines(a) = a

islinenumbernode(x) = x isa LineNumberNode