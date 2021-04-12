# TODO make it work for every pattern type
# TODO make it yield enodes only: ping pavel and marisa
# TODO STAGE IT! FASTER!
# TODO make it linear, use vectors and positions instead of arrays
# for register memory and for substitutions

using AutoHashEquals

abstract type Instruction end 

const Program = Vector{Instruction}

const Register = Int32

@auto_hash_equals struct ENodePat
    head::Any
    # args::Vector{Register} 
    args::UnitRange{Register}
end

@auto_hash_equals struct Bind <: Instruction
    reg::Register
    enodepat::ENodePat
end

@auto_hash_equals struct CheckClassEq <: Instruction
    left::Register
    right::Register
end

@auto_hash_equals struct Check <: Instruction
    reg::Register
    val::Any
end

@auto_hash_equals struct CheckType <: Instruction
    reg::Register
    type::Any
end


@auto_hash_equals struct Yield <: Instruction
    yields::Vector{Register}
end

function compile_pat(reg, p::PatTerm, ctx, count)
    # a = [gensym() for i in 1:length(p.args)]
    c = count[]
    a = c:(c+length(p.args) - 1)

    # println(a)
    # @assert length(a) == length(p.args)

    count[] = c + length(p.args)
    binder = Bind(reg, ENodePat(p.head, a))
    return vcat( binder, [compile_pat(reg, p2, ctx, count) for (reg, p2) in zip(a, p.args)]...)
end

function compile_pat(reg, p::PatVar, ctx, count)
    if ctx[p.idx] != -1
        return CheckClassEq(reg, ctx[p.idx])
    else
        ctx[p.idx] = reg
        return []
    end
end

function compile_pat(reg, p::PatTypeAssertion, ctx, count)
    if ctx[p.var.idx] != -1
        return CheckClassEq(reg, ctx[p.var.idx])
    else
        ctx[p.var.idx] = reg
        return CheckType(reg, p.type)
    end
end

# TODO works also for ground terms (?)!
# function compile_pat(reg, p::PatLiteral, ctx)
#     return Check(reg, p.val)
# end

function compile_pat(reg, p::PatLiteral, ctx, count)
    return Bind(reg, ENodePat(p.val, 0:-1))
end

# EXPECTS INDEXES OF PATTERN VARIABLES TO BE ALREADY POPULATED
function compile_pat(p::Pattern)
    pvars = patvars(p)
    nvars = length(pvars)

    count = Ref(2)
    ctx = fill(-1, nvars)

    # println("compiling pattern $p")
    # println(pvars)
    insns = compile_pat(1, p, ctx, count)
    # println("compiled pattern ctx is $ctx")
    return vcat(insns, Yield(ctx)), ctx, count[]
end


# =============================================================
# ================== INTERPRETER ==============================
# =============================================================



function interp_unstaged(g, instr::Yield, rest, σ, buf) 
    push!( buf, [σ[reg] for reg in instr.yields])
end

function interp_unstaged(g, instr::CheckClassEq, rest, σ, buf) 
    if σ[instr.left] == σ[instr.right]
        next(g, rest, σ, buf)
    end
end

# function interp_unstaged(g, instr::Check, rest, σ, buf) 
#     id, literal = σ[instr.reg]
#     eclass = geteclass(g, id)
#     for n in eclass.nodes 
#         if arity(n) == 0 && n.head == instr.val
#             # TODO bind literal here??
#             next(g, rest, σ, buf)
#         end
#     end 
# end

function interp_unstaged(g, instr::CheckType, rest, σ, buf) 
    id, literal = σ[instr.reg]
    eclass = geteclass(g, id)
    for (i, n) in enumerate(eclass.nodes)
        if arity(n) == 0 && typeof(n.head) <: instr.type
            σ[instr.reg] = (id, i)
            next(g, rest, σ, buf)
        end
    end 
end


function interp_unstaged(g, instr::Bind, rest, σ, buf) 
    ecid, literal = σ[instr.reg]
    for n in g[ecid] 
        if n.head == instr.enodepat.head && length(n.args) == length(instr.enodepat.args)
            for (i,v) in enumerate(instr.enodepat.args)
                σ[v] = (n.args[i], -1)
            end
            next(g, rest, σ, buf)
        end
    end
end

function next(g, rest, σ, buf)
    if length(rest) == 0 
        return nothing 
    end 
    return interp_unstaged(g, rest[1], @view(rest[2:end]), σ, buf)
end

# Global Right Hand Side function cache for dynamic rules.
# Now we're talking.
# TODO use a LRUCache?
const EMATCH_PROG_CACHE = IdDict{Pattern, Tuple{Program, Int64}}()
const EMATCH_PROG_CACHE_LOCK = ReentrantLock()

function getprogram(p::Pattern)
    lock(EMATCH_PROG_CACHE_LOCK) do
        if !haskey(EMATCH_PROG_CACHE, p)
            # println("cache miss!")
            program, ctx, σsize = compile_pat(p)
            EMATCH_PROG_CACHE[p] = (program, σsize)
        end
        return EMATCH_PROG_CACHE[p]
    end
end


function ematch(g::EGraph, p::Pattern, id::Int64)
    buf = Sub[]

    program, σsize = getprogram(p) 

    σ = fill((-1,-1), σsize)
    σ[1] = (id, -1)
    next(g, program, σ, buf)
    # println(buf)
    return buf
end