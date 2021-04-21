using Metatheory
using Metatheory.EGraphs
using Metatheory.Library

@metatheory_init ()

struct ZXTerm{I, O}
    head::Symbol
    args::Vector{Any}
end
ZXTerm{I, O}(h) where {I, O} = ZXTerm{I, O}(h, Any[])

Base.:(==)(t1::ZXTerm, t2::ZXTerm) = (
    ninput(t1) == ninput(t2) && 
    noutput(t1) == noutput(t2) &&
    t1.head === t2.head &&
    t1.args == t2.args
)

ninput(::Type{ZXTerm{I, O}}) where {I, O} = I
noutput(::Type{ZXTerm{I, O}})  where {I, O} = O
ninput(a::ZXTerm{I, O}) where {I, O} = I
noutput(a::ZXTerm{I, O})  where {I, O} = O

zspider(ninput, noutput, phase) = ZXTerm{ninput, noutput}(:Z, Any[phase])
xspider(ninput, noutput, phase) = ZXTerm{ninput, noutput}(:X, Any[phase])
hadamard() = ZXTerm{1, 1}(:H)
id(n) = ZXTerm{n, n}(:I)

compose(a, b, c...) = compose(compose(a, b), c...)
function compose(a::ZXTerm, b::ZXTerm)
    @assert noutput(a) == ninput(b)
    return ZXTerm{ninput(a), noutput(b)}(:(⋅), [a, b])
end

otimes(a, b, c...) = otimes(otimes(a, b), c...)
function otimes(a::ZXTerm, b::ZXTerm)
    input_size = ninput(a) + ninput(b)
    output_size = noutput(a) + noutput(b)
    return ZXTerm{input_size, output_size}(:(⊗), [a, b])
end

using Metatheory.TermInterface
TermInterface.gethead(t::ZXTerm) = :call
TermInterface.getargs(t::ZXTerm) = [t.head, t.args...]
TermInterface.istree(t::ZXTerm) = true
function TermInterface.getmetadata(t::ZXTerm{I, O}) where {I, O}
    t.head in (:X, :Z) && return (; :ninput => I, :noutput => O, :phase => t.args[])
    return (; :ninput => I, :noutput => O)
end
TermInterface.arity(t::ZXTerm) = length(getargs(t))

struct ZXAnalysis <: AbstractAnalysis end

function EGraphs.make(an::Type{ZXAnalysis}, g::EGraph, n::ENode{T}) where T
    sym = n.head
    if !(T <: ZXTerm)
        t = sym
        return t
    end

    nmeta = getmetadata(n)
    return nmeta
end
function EGraphs.join(an::Type{ZXAnalysis}, from, to)
    if haskey(from, :ninput) && haskey(from, :noutput)
        @assert haskey(to, :ninput) && haskey(to, :noutput)
        @assert from.ninput == to.ninput && from.noutput == to.noutput
        return (; :ninput => to.ninput, :noutput => to.noutput)
    end
    return from
end
EGraphs.islazy(x::Type{ZXAnalysis}) = true

function infer(t::ZXTerm)
    g = EGraph(t)
    analyze!(g, ZXAnalysis)
    getdata(geteclass(g, g.root), ZXAnalysis)
end

h = hadamard()
c = compose(otimes(h, zspider(1, 1, pi)), otimes(id(1), zspider(1, 2, 0)))
G = EGraph(c)

noutput(c)

analyze!(G, ZXAnalysis)
@test infer(c).ninput == ninput(c) && infer(c).noutput == noutput(c)