abstract type TypeLevel end
struct TLCons{Hd, Tl} <: TypeLevel end
struct TLNil <: TypeLevel end
struct TLVal{Val} <: TypeLevel end
struct TLSExp{Fn, Args} <: TypeLevel end

function typelevellist(l)
    foldr(l, init=TLNil) do each, prev
        TLCons{each, prev}
    end
end

function expr2typelevel(x)
    r = expr2typelevel
    @match x begin
        Expr(hd, tl...) =>
            let hd = r(hd),
                tl = map(r, tl) |> typelevellist,
                f = TLVal{Expr},
                args = TLCons{hd, tl}
            TLSExp{f, args}
            end
        ln :: LineNumberNode =>
            let f = TLVal{LineNumberNode},
               args = [
                    r(ln.line),
                    r(ln.file)
                ] |> typelevellist
            TLSExp{f, args}
            end
        x::QuoteNode =>
            let f = TLVal{QuoteNode},
                args = [r(x.value)] |> typelevellist

            TLSExp{f, args}
            end
        a => TLVal{a}
    end
end


function interpret(t::Type{TLNil})
    []
end

function interpret(t::Type{TLVal{Val}}) where Val
    Val
end

function interpret(t::Type{TLCons{Hd, Tl}}) where {Hd, Tl}
    tl = interpret(Tl)
    @assert tl isa Vector
    [interpret(Hd), tl...]
end

function interpret(t::Type{TLSExp{Fn, Args}}) where {Fn, Args}
    args = interpret(Args)
    @assert args isa Vector
    interpret(Fn)(args...)
end