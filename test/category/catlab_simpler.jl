using Catlab
using Catlab.Theories
using Catlab.Syntax

using Metatheory, Metatheory.EGraphs
@metatheory_init ()

# WE HAVE TO REDEFINE THE SYNTAX TO AVOID ASSOCIATIVITY AND N-ARY FUNCTIONS
import Catlab.Theories: id, compose, otimes, ⋅, braid, σ, ⊗, Ob, Hom
@syntax SMC{ObExpr,HomExpr} SymmetricMonoidalCategory begin
end

A, B, C = Ob(SMC, :A, :B, :C)
X, Y, Z = Ob(SMC, :X, :Y, :Z)

f = Hom(:f, A, B)

function gat_to_expr(ex::ObExpr{:generator})
    @assert length(ex.args) == 1
    return ex.args[1]
end

function gat_to_expr(ex::ObExpr{H}) where {H}
    return Expr(:call, head(ex), map(gat_to_expr, ex.args)...)
end

function gat_to_expr(ex::HomExpr{H}) where {H}
    @assert length(ex.type_args) == 2
    expr = Expr(:call, head(ex), map(gat_to_expr, ex.args)...)
    type_ex = Expr(:call, :→, map(gat_to_expr, ex.type_args)...)
    return Expr(:call, :~, expr, type_ex)
end

function gat_to_expr(ex::HomExpr{:generator})
    expr = Expr(:call, ex.args[1])
    type_ex = Expr(:call, :→, map(gat_to_expr, ex.type_args)...)
    return Expr(:call, :~, expr, type_ex)
end


gat_to_expr(x) = x

gat_to_expr(id(Z)) == :(id(Z)~(Z→Z)) 

gat_to_expr(id(Z) ⋅ f)

gat_to_expr(id(A ⊗ B))

gat_to_expr(id(A) ⊗ id(B))


tt = SMC.theory() |> theory

function axiom_to_rule(theory, axiom)
    lhs = tag_expr(theory, axiom, axiom.left) |> Pattern
    rhs = tag_expr(theory, axiom, axiom.right) |> Pattern
    op = axiom.name
    @assert op == :(==)
    EqualityRule(lhs, rhs)
end

# base case
function get_concrete_type_expr(theory, x::Symbol, axiom, loc_ctx = Dict{Code, Code}())
    ctx = axiom.context
    t = ctx[x]
    t === :Ob && (t = x)
    loc_ctx[x] = t
    return t
end

const Code = Union{Symbol, Expr}

function get_concrete_type_expr(theory, x::Expr, axiom, loc_ctx = Dict{Code, Code}())
    #local context
    ctx = axiom.context
    # loc_ctx = Dict{Code, Code}()
    @assert x.head == :call
    f = x.args[1]
    rest = x.args[2:end]
    # recursion case - inductive step (?)
    for a in rest
        t = get_concrete_type_expr(theory, a, axiom, loc_ctx)
        loc_ctx[a] = t

        println("$a ~ $t")
    end

    loc_ctx[x] = gat_type_inference(theory, f, [loc_ctx[a] for a in rest])
    println("$x ~ $(loc_ctx[x])")

    # get the corresponding TermConstructor from theory.terms
    # for each arg in `rest`, instantiate the term.params with term.context
    # GAT.replace_types(Dict(:A => :Z), term)
    # instantiate term.typ

    # :(Hom(A,B)) instead of :(A \to B)

    return loc_ctx[x]
end

function gat_type_inference(theory, head, args)
    for t in theory.terms
        t.name === head && return gat_type_inference(t, head, args)
    end
    @error "can not find $head in the theory"
end

function gat_type_inference(t::GAT.TermConstructor, head, args)
    @assert length(t.params) == length(args) && t.name === head
    bindings = Dict()
    for i = 1:length(args)
        template = t.context[t.params[i]]
        template === :Ob && (template = t.params[i])
        # @show template
        update_bindings!(bindings, template, args[i])
    end
    # @show bindings
    return GAT.replace_types(bindings, t).typ
end
function update_bindings!(bindings, template::Expr, target::Expr)
    @assert length(template.args) == length(target.args)
    for i = 1:length(template.args)
        update_bindings!(bindings, template.args[i], target.args[i])
    end
end
function update_bindings!(bindings, template::Symbol, target::Symbol)
    bindings[template] = target
end

ax = tt.axioms[1]
get_concrete_type_expr(tt, ax.left, ax)

tag_expr(x, t) = :($x ~ $t)

function tag_expr(theory, axiom, expr::Expr)
    # type == axiom.context[x]
    if Meta.isexpr(expr, :call)
        f = expr.args[1]
        rest = expr.args[2:end]

        term = findfirst(x -> x.name == name && length(rest) == length(params), theory.terms)
        

        for (i, arg) in enumerate(rest)
            # NOT FINISHED
        end 


        ex = Expr(:call, f, 
            map(x -> tag_expr(axiom, x), expr.args[2:end])...)
        return ex
    else 
        return Expr(expr.head, 
            map(x -> tag_expr(axiom, x), expr.args)...)
    end
end

function tag_expr(axiom, x::Symbol)
    type = axiom.context[x]
    if type == :Ob 
        return (x, :Ob) 
    elseif Meta.isexpr(type, :call) && type.args[1] == :Hom
        t = Expr(:call, :→, type.args[2:end]...)
        return (x, t)
    else 
        error("unrecognized GAT type")
    end
end

ax = tt.axioms[7]
tag_expr(ax, ax.left)
tag_expr(ax, ax.right)

axiom_to_rule.(tt.axioms)

# ====================================================
# TEST 


function simplify(ex, syntax)
    t = gen_theory(syntax)
    g = EGraph(ex)
    analyze!(g, CatlabAnalysis)
    params=SaturationParams(timeout=1)
    saturate!(g, t, params; mod=@__MODULE__)
    extract!(g, astsize)
end

Metatheory.options.printiter = true

ex = f ⋅ id(B)
simplify(ex, SMC) == f

ex = id(A) ⋅ f ⋅ id(B)
simplify(ex, SMC) == f

ex = σ(A,B) ⋅ σ(B,A)
simplify(ex, SMC) == id(A ⊗ B)


# ======================================================
# another test

using Catlab.Graphics

l = (σ(C,B) ⊗ id(A)) ⋅ (id(B) ⊗ σ(C,A)) ⋅ (σ(B,A) ⊗ id(C))
r = (id(C) ⊗ σ(B,A)) ⋅ (σ(C,A) ⊗ id(B)) ⋅ (id(A) ⊗ σ(C,B))

to_graphviz(l)
to_graphviz(r)

g = EGraph()
analyze!(g, CatlabAnalysis)
l_ec = addexpr!(g, l)
r_ec = addexpr!(g, r)

in_same_class(g, l_ec, r_ec)

saturate!(g, gen_theory(SMC), SaturationParams(timeout=1, eclasslimit=6000); mod=@__MODULE__)

ll = extract!(g, astsize; root=l_ec.id) 
rr = extract!(g, astsize; root=r_ec.id) 

# ======================================================
# another test

# WE HAVE TO REDEFINE THE SYNTAX TO AVOID ASSOCIATIVITY AND N-ARY FUNCTIONS
import Catlab.Theories: id, compose, otimes, ⋅, braid, σ, ⊗, Ob, Hom, pair, proj1, proj2
@syntax BPC{ObExpr,HomExpr} BiproductCategory begin
end
A, B, C = Ob(BPC, :A, :B, :C)
f = Hom(:f, A, B)
k = Hom(:k, B, C)


l = Δ(A) ⋅ (delete(A) ⊗ id(A)) 
r = id(A)


g = EGraph(l)
analyze!(g, CatlabAnalysis)


saturate!(g, gen_theory(BPC), SaturationParams(timeout=1, eclasslimit=6000); mod=@__MODULE__)

extract!(g, astsize)

# ======================================================
# another test

l = σ(A, B ⊗ C)
# r = σ(B,A) ⊗ id(C)
r = (σ(A,B) ⊗ id(C)) ⋅ (id(B) ⊗ σ(A,C))
# r = σ(B ⊗ C, A)

to_composejl(l)
to_composejl(r)

g = EGraph(ex)
analyze!(g, CatlabAnalysis)
l_ec = addexpr!(g, l)
r_ec = addexpr!(g, r)


saturate!(g, gen_theory(SMC), SaturationParams(timeout=1, eclasslimit=6000); mod=@__MODULE__)

extract!(g, astsize; root=l_ec.id)

extract!(g, astsize; root=r_ec.id)




# ====================================================
# TEST 
cc = gen_theory(FreeCartesianCategory)

A, B, C = Ob(FreeCartesianCategory, :A, :B, :C)
f = Hom(:f, A, B)

g = EGraph()
analyze!(g, CatlabAnalysis)
ex = id(A) ⊗ id(B)
to_composejl(ex)

l_ec = addexpr!(g, ex)
saturate!(g, cc, SaturationParams(timeout=2); mod=@__MODULE__)
extract!(g, astsize; root=l_ec.id)


ex = pair(proj1(A, B), proj2(A, B))
to_composejl(ex)
r_ec = addexpr!(g, ex)
saturate!(g, cc; mod=@__MODULE__)
extract!(g, astsize; root=r_ec.id)

