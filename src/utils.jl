function split_args_kwargs(args)
    @match args begin
        [Expr(:parameters, kwargs...), args...] => (args, kwargs)
        _ => (args, [])
    end
end