using Catlab
using Catlab.Theories

@signature ZXCategory{Ob,Hom} <: DaggerCompactCategory{Ob,Hom} begin
    # Argument α is the phase, usually <: Real
    zphase(A::Ob, α)::(A → A)
    zcopy(A::Ob, α)::(A → (A⊗A))
    zdelete(A::Ob, α)::(A → munit())
    zmerge(A::Ob, α)::((A⊗A) → A)
    zcreate(A::Ob, α)::(munit() → A)
    
    xphase(A::Ob, α)::(A → A)
    xcopy(A::Ob, α)::(A → (A⊗A))
    xdelete(A::Ob, α)::(A → munit())
    xmerge(A::Ob, α)::((A⊗A) → A)
    xcreate(A::Ob, α)::(munit() → A)
    
    hadamard(A::Ob)::(A → A)
end

# Convenience methods for phaseless spiders.
zcopy(A) = zcopy(A,0)
zdelete(A) = zdelete(A,0)
zmerge(A) = zmerge(A,0)
zcreate(A) = zcreate(A,0)

xcopy(A) = xcopy(A,0)
xdelete(A) = xdelete(A,0)
xmerge(A) = xmerge(A,0)
xcreate(A) = xcreate(A,0);

@syntax ZXCalculus{ObExpr,HomExpr} ZXCategory begin
    otimes(A::Ob, B::Ob) = associate_unit(new(A,B), munit)
    otimes(f::Hom, g::Hom) = associate(new(f,g))
    compose(f::Hom, g::Hom) = associate(new(f,g; strict=true))
end

using Metatheory, Metatheory.EGraphs
@metatheory_init ()

# Custom type APIs for the GATExpr
using Metatheory.TermInterface
TermInterface.gethead(t::ObExpr) = :call
TermInterface.getargs(t::ObExpr) = [head(t), t.args...]
TermInterface.gethead(t::HomExpr) = :call
TermInterface.getargs(t::HomExpr) = [head(t), t.args...]

abstract type CatType end
struct ObType <: CatType
    ob
    mod
end
struct HomType <: CatType
    codom
    dom
    mod
end

# Type information will be stored in the metadata
function TermInterface.getmetadata(t::HomExpr)
    return HomType(t.type_args[1], t.type_args[2], typeof(t).name.module)
end
TermInterface.getmetadata(t::ObExpr) = ObType(t, typeof(t).name.module)
TermInterface.istree(t::GATExpr) = true
TermInterface.arity(t::GATExpr) = length(getargs(t))

struct CatlabAnalysis <: AbstractAnalysis end
function EGraphs.make(an::Type{CatlabAnalysis}, g::EGraph, n::ENode{T}) where T
    !(T <: GATExpr) && return t
    return getmetadata(n)
end
EGraphs.join(an::Type{CatlabAnalysis}, from, to) = from
EGraphs.islazy(x::Type{CatlabAnalysis}) = false

function infer(t::GATExpr)
    g = EGraph(t)
    analyze!(g, CatlabAnalysis)
    getdata(geteclass(g, g.root), CatlabAnalysis)
end

function EGraphs.extractnode(n::ENode{T}, extractor::Function) where {T <: ObExpr}
    @assert n.head == :call
    return getmetadata(n).ob
end

function EGraphs.extractnode(n::ENode{T}, extractor::Function) where {T <: HomExpr}
    @assert n.head == :call
    nargs = extractor.(n.args)
    nmeta = getmetadata(n)
    return nmeta.mod.Hom{nargs[1]}(nargs[2:end], GATExpr[nmeta.codom, nmeta.dom])
end

# function EGraphs.instantiateterm(g::EGraph, pat::PatTerm,  T::Type{H{K}}, sub::Sub, rule::Rule) where {H <: GATExpr, K}
# # TODO
# end

t = Metatheory.@theory begin
    compose(hadamard(A), hadamard(A)) |> 
    begin
        analyze!(_egraph, Main.CatlabAnalysis)
        d = getdata(A, Main.CatlabAnalysis)
        return d.mod.id(d.ob)
    end
end

A = Ob(ZXCalculus.Ob, :A)
h = hadamard(A)
c = h ⋅ h
G = EGraph(c)
infer(zdelete(A)).codom == A

saturate!(G, t)
ex = extract!(G, astsize)
ex == id(A)