function split_args_kwargs(args)
    i_ = findfirst(x -> Meta.isexpr(x, :parameter), args)
    i = i_ === nothing ? 0 : i_
    (args[i+1:end], args[1:i])
end
