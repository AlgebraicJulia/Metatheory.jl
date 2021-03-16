mutable struct Rule
    left::Any
    right::Any
    expr::Expr # original expression
    mode::Symbol # can be :symbolic or :dynamic
    right_fun::Union{Nothing, Dict{Module, Tuple{Vector{Symbol}, Function}}}
end

import Base.==
==(a::Rule, b::Rule) = (a.expr == b.expr) && (a.mode == b.mode)

# operator symbols for simple term rewriting
const rewrite_syms = [:(=>)]
# operator symbols for regular pattern matching rules, "dynamic rules"
# that eval the right side at reduction time.
# might be used to implement big step semantics
const dynamic_syms = [:(|>)]

# symbols for bidirectional equality
const equational_syms = [:(==)]

# symbols for anti-rules
const inequality_syms = [:(!=), :(≠)]

function getmode(r::Expr)
    op = gethead(r)
    if op ∈ dynamic_syms # right hand execution, dynamic rules in egg
        :dynamic
    elseif op ∈ rewrite_syms # right side is quoted, symbolic replacement
        :symbolic
    elseif op ∈ equational_syms
        :equational
    elseif op ∈ inequality_syms
        :unequal
    else
        error(`rule "$r" is not in valid form.\n`)
    end
end


"""
Construct a `Rule` from a quoted expression.
You can also use the [`@rule`] macro to
create a `Rule`.
## Symbolic Rules

Rules defined as `left_hand => right_hand` are
called `symbolic` rules. Application of a `symbolic` Rule
is a replacement of the `left_hand` pattern with
the `right_hand` substitution, with the correct instantiation
of pattern variables. Function call symbols are not treated as pattern
variables, all other identifiers are treated as pattern variables.
Literals such as `5, :e, "hello"` are not treated as pattern
variables.

## Dynamic Rules

Rules defined as `left_hand |> right_hand` are
called `dynamic` rules. Dynamic rules behave like anonymous functions.
Instead of a symbolic substitution, the right hand of
a dynamic `|>` rule is evaluated during rewriting:
matched values are bound to pattern variables as in a
regular function call. This allows for dynamic computation
of

## Type Assertions

Type assertions are supported in the left hand of rules
to match and access literal values both when using classic
rewriting and EGraph based rewriting.
To use a type assertion pattern, add `::T` after
a pattern variable in the `left_hand` of a rule.

---

## Examples

Symbolic rule
```julia
Rule(:(a * b => b * a))
```

Equational rule
```julia
Rule(:(a * b == b * a))
```

Dynamic rule
```julia
Rule(:(a::Number * b::Number |> a*b))
```
"""
function Rule(e::Expr; mod::Module=@__MODULE__)
    e = rmlines(copy(e))
    mode = gethead(e)
    l, r = e.args[isexpr(e, :call) ? (2:3) : (1:2)]

    right_fun = nothing

    mode = getmode(e)

    l = interpolate_dollar(l, mod)
    l = df_walk(x -> eval_types_in_assertions(x, mod), l; skip_call=true)
    # TODO FIXME move right_fun dictionary to be module-wise and not for each rule
    mode == :dynamic && (right_fun = Dict(mod => genrhsfun(l, r, mod)))

    e.args[isexpr(e, :call) ? 2 : 1] = l
    return Rule(l, r, e, mode, right_fun)
end

macro rule(e)
    Rule(e; mod=__module__)
end

# string representation of the rule
function Base.show(io::IO, x::Rule)
    println(io, "Rule(:(", x.expr, "))")
end

"""
Generates a tuple containing the list of formal parameters (`Symbol`s)
and the [`RuntimeGeneratedFunction`](@ref) corresponding to the right hand
side of a `:dynamic` [`Rule`](@ref).
"""
function genrhsfun(left, right, mod::Module)
    # remove type assertions in left hand
    lhs = remove_assertions(left)
    # collect variable symbols in left hand
    lhs_vars = Set{Symbol}()
    df_walk( x -> (if x isa Symbol; push!(lhs_vars, x); end; x), left; skip_call=true )
    params = Expr(:tuple, :_lhs_expr, :_egraph, lhs_vars...)

    ex = :($params -> $right)
    (collect(lhs_vars), closure_generator(mod, ex))
end


# TODO is there anything better than eval to use here?
"""
When creating a theory, type assertions in the left hand contain symbols.
We want to replace the type symbols with the real type values, to fully support
the subtyping mechanism during pattern matching.
"""
function eval_types_in_assertions(x, mod::Module)
    if isexpr(x, :(::))
        !(x.args[1] isa Symbol) && error("Type assertion is not on metavariable")
        x.args[2] isa Type && (return x)
        Expr(:(::), x.args[1], getfield(mod, x.args[2]))
    else x
    end
end

iscond(e) = (isexpr(e, :call) && e.args[1] == :(==)) #||
    #(isexpr(e, :call) && e.args[1] == :(≠))

macro when(expr)
    @assert isexpr(expr, :call)
    op = expr.args[1]
    expr = rmlines(expr)
    if op == :⊢     # syntactical consequence. supported only in egraphs
        conditions = []
        env = expr.args[2]
        # extract conditions from env
        # support (a=b;c=d) [a=b c=d] and [a=b, c=d]
        if isexpr(env, :block) || isexpr(env, :vect) || isexpr(env, :hcat)
            for cond ∈ env.args
                if iscond(cond)
                    push!(conditions, cond)
                else
                    error("malformed condition $cond")
                end
            end
        # support a signle a=b or a≠b
        elseif iscond(env)
            push!(conditions, env)
        else
            error("malformed conditions $env")
        end
        # get rule on right
        rule = expr.args[3]
        op = gethead(rule)
        mode = getmode(rule)
        l, r = rule.args[isexpr(rule, :call) ? (2:3) : (1:2)]


        #
        # println(l)
        # println(r)
        # println(op)
        # println(mode)
        # println(conditions)

        if mode != :symbolic && mode != :dynamic
            error("only conditional dynamic or symbolic rules are supported")
        end

        cond = make_egraph_condition(conditions)
        # println(cond)

        if mode == :dynamic
            ret = :(($op)($l, if $cond
                $r
                else _lhs_expr end)) |> esc |> rmlines
            ret
        end

    end
end

"""
Generate a single expression containing an equality/inequality condition on the
current egraph for a conditional rule and the `@when` macro
"""
# TODO nun va bene, invece di find devi fare tutti gli addexpr
# e poi controllare le uguaglianze sulle EClass alla fine. usa gensym
function make_egraph_condition(conditions)
    egraphed_conditions = []
    for x ∈ conditions
        op, l, r = x.args[1:3]

        ll = df_walk( x -> (if x isa Symbol; dollar(x); end; x), l; skip_call=true )

        l |> dump
        ll |> dump

        op == :≠ && (op = :(!=))
        push!(egraphed_conditions,
            :(($op)(find(_egraph, $l), find(_egraph, $r))))
    end

    foldr((x,y) -> :($x && $y), egraphed_conditions)
end

export @when
export iscond
