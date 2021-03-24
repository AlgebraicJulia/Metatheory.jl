using DataStructures
using Base.Meta

import Base.ImmutableDict

# @auto_hash_equals struct EClass
#     id::Int64
# end

struct ENode{X}
    head::Any
    args::Vector{Int64}
    metadata::Union{Nothing, NamedTuple}
    hash::Ref{UInt} # hash cache
    ENode{T}(h, a, m) where T = new{T}(h, a, m, Ref{UInt}(0))
end

function ENode(e, c_ids::AbstractVector{Int64})
    # @assert length(getargs(e)) == length(c_ids)
    # static_args = MVector{length(c_ids), Int64}(c_ids...)
    ENode{typeof(e)}(gethead(e), c_ids, getmetadata(e))
end

ENode(e) = ENode(e, Int64[])

ENode(a::ENode) =
    error("constructor of ENode called on enode. This should never happen")



function Base.:(==)(a::ENode, b::ENode)
    isequal(a.metadata, b.metadata) && isequal(a.args, b.args) && 
    isequal(a.head, b.head)
end

# This optimization comes from SymbolicUtils
# The hash of an enode is cached to avoid recomputing it.
# Shaves off a lot of time in accessing dictionaries with ENodes as keys.
function Base.hash(t::ENode{T}, salt::UInt) where {T}
    !iszero(salt) && return hash(hash(t, zero(UInt)), salt)
    h = t.hash[]
    !iszero(h) && return h
    h′ = hash(t.args, hash(t.head, hash(T, salt)))
    t.hash[] = h′
    return h′
end

TermInterface.arity(n::ENode) = length(n.args)


# string representation of the rule
function Base.show(io::IO, x::ENode)
    print(io, "(", x.head)
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
