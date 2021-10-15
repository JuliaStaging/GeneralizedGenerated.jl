struct Closure{F,Free} <: Function
    frees::Free
end

function (closure::Closure{F,X})(args...; kwargs...) where {F,X}
    F(closure.frees..., args...; kwargs...)
end
