using DataStructures
using Base.Meta

import Base.ImmutableDict

const EClassId = Int64

# struct ENode{T, M}
mutable struct ENode{T}
    head::Any
    args::Vector{EClassId}
    # metadata::M
    # the nodes where it came from 
    proof_src::Vector{ENode}
    # the rules that generated this enode
    proof_rules::Vector{Rule}
    # the enodes that were generated by this enode
    proof_trg::Vector{ENode}
    hash::Ref{UInt} # hash cache
end

function ENode{T}(head, c_ids::AbstractVector{EClassId}, ps=[], pr=[], pt=[]) where {T}
    # static_args = MVector{length(c_ids), Int64}(c_ids...)
    # m = getmetadata(e)
    ENode{T}(head, c_ids, ps, pr, pt, Ref{UInt}(0))
end

ENode(a) = ENode{typeof(a)}(a, EClassId[])


ENode(a::ENode) =
    error("constructor of ENode called on enode. This should never happen")

function Base.:(==)(a::ENode, b::ENode)
    isequal(a.args, b.args) && 
    isequal(a.head, b.head)
end

# ===============================================================
# proof functions 
# ===============================================================

function addproofsrc!(n::ENode{T}, src::ENode) where {T}
    push!(n.proof_src, src)
end

function addproofsrc!(n::ENode{T}, src::Vector{ENode}) where {T}
    append!(n.proof_src, src)
end

function addprooftrg!(n::ENode{T}, trg::ENode) where {T}
    push!(n.proof_trg, trg)
end

function addprooftrg!(n::ENode{T}, trg::Vector{ENode}) where {T}
    append!(n.proof_trg, trg)
end

function addproofrule!(n::ENode{T}, rule::Rule) where {T}
    push!(n.proof_rules, rule)
end

function hasproofdata(n::ENode)
    !(isempty(n.proof_src) && isempty(n.proof_trg) && isempty(n.proof_rules)) 
end

function mergeproof!(target::ENode, source::ENode)
    union!(target.proof_src, source.proof_src)
    union!(target.proof_trg, source.proof_trg)
    union!(target.proof_rules, source.proof_rules)
end


# This optimization comes from SymbolicUtils
# The hash of an enode is cached to avoid recomputing it.
# Shaves off a lot of time in accessing dictionaries with ENodes as keys.
function Base.hash(t::ENode{T}, salt::UInt) where {T}
    !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
    h = t.hash[]
    !iszero(h) && return h
    # h′ = hash(t.args,  hash(t.metadata, hash(t.head, hash(T, salt))))
    h′ = hash(t.args,  hash(t.head, hash(T, salt)))
    t.hash[] = h′
    return h′
end

TermInterface.arity(n::ENode) = length(n.args)
# TermInterface.getmetadata(n::ENode) = n.metadata
# TermInterface.metadatatype(n::ENode{T,M}) where {T,M} = M

termtype(x::ENode{T}) where T = T

function Base.show(io::IO, x::ENode{T}) where {T}
    print(io, "ENode{$T}(", x.head)
    n = arity(x)
    if n == 0
        print(io, ")")
        return
    else
        print(io, " ")
    end
    for i ∈ 1:n
        if i < n
            print(io, x.args[i], " ")
        else
            print(io, x.args[i], ")")
        end
    end
end
