using AutoHashEquals

@auto_hash_equals struct ENodePat
    head::Symbol
    args::Vector{Symbol}
end

@auto_hash_equals struct Bind 
    eclass::Symbol
    enodepat::ENodePat
end

@auto_hash_equals struct CheckClassEq
    eclass1::Symbol
    eclass2::Symbol
end

@auto_hash_equals struct Yield
    yields::Dict{Symbol, Symbol}
end

function compile_pat(eclass, p::PatTerm, ctx)
    a = [gensym() for i in 1:length(p.args) ]
    return vcat(  Bind(eclass, ENodePat(p.head, a)) , [compile_pat(eclass, p2, ctx) for (eclass , p2) in zip(a, p.args)]...)
end

function compile_pat(eclass, p::PatVar, ctx)
    if haskey(ctx, p.name)
        return CheckClassEq(eclass, ctx[p.name])
    else
        ctx[p.name] = eclass
        return []
    end
end

function compile_pat(p::Pattern)
    ctx = Dict()
    insns = compile_pat(:start, p, ctx)
    println("compiled pattern ctx is $ctx")
    return vcat(insns, Yield(ctx)), ctx
end

function interp_unstaged(G, program, ctx, buf) 
    if length(insns) == 0
        return 
    end
    instr = insns[1]
    prog_tail = insns[2:end]
    if instr isa Bind
        for enode in G[ctx[insn.eclass]] 
            if enode.head == insn.enodepat.head && length(enode.args) == length(insn.enodepat.args)
                for (n,v) in enumerate(insn.enodepat.args)
                    ctx[v] = enode.args[n]
                end
                interp_unstaged(G,  insns, ctx, buf)
            end
        end
    elseif insn isa Yield
        push!( buf, [key => ctx[val] for (key, val) in insn.yields])
    elseif insn isa CheckClassEq
        if ctx[insn.eclass1] == ctx[insn.eclass2]
            interp_unstaged(G, insns, ctx, buf)
        end
    end
end

function interp_unstaged(g::EGraph, program, id)
    buf = []
    ctx = Dict{Symbol,Int64}([:start => id])
    interp_unstaged(g::EGraph, program, ctx, buf)
    return buf
end

function ematch(g::EGraph, p::Pattern, id::Int64)
    program, _ = compile_pat(p)
    out = interp_unstaged(g, program, id)
    println(out)
    return out
end