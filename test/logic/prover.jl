using Metatheory
using Metatheory.EGraphs
using Metatheory.Classic

function prove(t, ex, steps=1, timeout=10, eclasslimit=5000)
    params = SaturationParams(timeout=timeout, eclasslimit=eclasslimit, 
        scheduler=Schedulers.ScoredScheduler, schedulerparams=(8,2, Schedulers.exprsize))
    hist = UInt64[]
    push!(hist, hash(ex))
    for i ∈ 1:steps
        g = EGraph(ex)
        saturate!(g, t, params)
        ex = extract!(g, astsize)
        println(ex)
        if !TermInterface.istree(ex)
            return ex
        end
        if hash(ex) ∈ hist
            println("loop detected")
            return ex
        end
        push!(hist, hash(ex))
    end
    return ex
end

