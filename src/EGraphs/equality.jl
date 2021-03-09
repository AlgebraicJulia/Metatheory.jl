function areequal(theory::Vector{Rule}, exprs...;
    timeout=options[:timeout], sizeout=options[:sizeout],
    matchlimit=options[:matchlimit], mod=@__MODULE__)
    G = EGraph(exprs[1])
    areequal(G, theory, exprs...;
        timeout=timeout, matchlimit=matchlimit, sizeout=sizeout, mod=mod)
end

function areequal(G::EGraph, t::Vector{Rule}, exprs...;
    timeout=options[:timeout], sizeout=options[:sizeout],
    matchlimit=options[:matchlimit], mod=@__MODULE__)
    @log "Checking equality for " exprs
    if length(exprs) == 1; return true end

    ids = []
    for i ∈ exprs
        ec = addexpr!(G, i)
        push!(ids, ec.id)
    end

    # rebuild!(G)

    @log "starting saturation"

    alleq = () -> (all(x -> in_same_set(G.U, ids[1], x), ids[2:end]))

    report = saturate!(G, t; timeout=timeout, matchlimit=matchlimit,
        sizeout=sizeout, stopwhen=alleq, mod=mod)

    alleq()
end

import ..gettheory

macro areequal(theory, exprs...)
    t = gettheory(theory, __module__; compile=false)
    areequal(t, exprs...; mod=__module__)
end

macro areequalg(G, theory, exprs...)
    t = gettheory(theory, __module__; compile=false)
    areequal(getfield(__module__, G), t, exprs...; mod=__module__)
end
