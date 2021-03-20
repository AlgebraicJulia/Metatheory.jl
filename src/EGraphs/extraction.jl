"""
A basic cost function, where the computed cost is the size
(number of children) of the current expression.
"""
function astsize(n::ENode, g::EGraph, an::Type{<:AbstractAnalysis})
    cost = 1 + ariety(n)
    for id ∈ n.args
        eclass = geteclass(g, id)
        !hasdata(eclass, an) && (cost += Inf; break)
        cost += last(getdata(eclass, an))
    end
    return cost
end

"""
A basic cost function, where the computed cost is the size
(number of children) of the current expression, times -1.
Strives to get the largest expression
"""
astsize_inv(n::ENode, g::EGraph, an::Type{<:AbstractAnalysis}) = -1 * astsize(n, g, an)


"""
An [`AbstractAnalysis`](@ref) that computes the cost of expression nodes
and chooses the node with the smallest cost for each E-Class.
This abstract type is parametrised by a function F.
This is useful for the analysis storage in [`EClass`](@ref)
"""
abstract type ExtractionAnalysis{F} <: AbstractAnalysis end

make(a::Type{ExtractionAnalysis{F}}, g::EGraph, n::ENode) where F = (n, F(n, g, a))

join(a::Type{<:ExtractionAnalysis}, from, to) = last(from) <= last(to) ? from : to

islazy(a::Type{<:ExtractionAnalysis}) = true

function rec_extract(g::EGraph, an::Type{<:ExtractionAnalysis}, id::Int64)
    eclass = geteclass(g, id)
    (cn, ck) = getdata(eclass, an)
    (ariety(cn) == 0 || ck == Inf) && return cn.head
    extractor = a -> rec_extract(g, an, a)
    extractnode(cn, extractor)
end

# TODO document how to extract
# TODO maybe extractor can just be the array of extracted children?
function extractnode(n::ENode{Expr}, extractor::Function)::Expr
    expr_args = []
    expr_head = n.head

    if n.metadata.iscall
        push!(expr_args, n.head)
        expr_head = :call
    end

    for a ∈ n.args
        # id == a && (error("loop in extraction"))
        push!(expr_args, extractor(a))
    end

    return Expr(expr_head, expr_args...)
end

function extractnode(n::ENode{T}, extractor::Function) where T
    if ariety(n) > 0
        error("ENode extraction is not defined for non-literal type $T")
    end
    return n.head
end

"""
Given an [`ExtractionAnalysis`](@ref), extract the expression
with the smallest computed cost from an [`EGraph`](@ref)
"""
function extract!(g::EGraph, a::Type{ExtractionAnalysis{F}} where F; root=-1)
    if root == -1
        root = g.root
    end
    analyze!(g, a, root)
    !(a ∈ g.analyses) && error("Extraction analysis is not associated to EGraph")
    rec_extract(g, a, g.root)
end

"""
Given a cost function, extract the expression
with the smallest computed cost from an [`EGraph`](@ref)
"""
function extract!(g::EGraph, costfun::Function; root=-1)
    extran = ExtractionAnalysis{costfun}
    extract!(g, extran; root=root)
end

macro extract(expr, theory, costfun)
    quote
        let g = EGraph($expr)
            saturate!(g, $theory)
            ex = extract!(g, $costfun)
            (g, ex)
        end
    end |> esc
end
