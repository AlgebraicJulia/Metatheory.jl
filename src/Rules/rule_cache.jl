# Global Right Hand Side function cache for dynamic rules.
# Now we're talking.
# TODO use a LRUCache?
const RHS_FUNCTION_CACHE = IdDict{Tuple{DynamicRule, Module}, Function}()
const RHS_FUNCTION_CACHE_LOCK = ReentrantLock()

function getrhsfun(r::DynamicRule, m::Module)
    lock(RHS_FUNCTION_CACHE_LOCK) do
        p = (r,m)
        if !haskey(RHS_FUNCTION_CACHE, p)
            z = genrhsfun(r, m)
            RHS_FUNCTION_CACHE[p] = z
        end
        return RHS_FUNCTION_CACHE[p]
    end
end


"""
Generates a [`RuntimeGeneratedFunction`](https://github.com/SciML/RuntimeGeneratedFunctions.jl/) corresponding to the right hand
side of a `:dynamic` [`Rule`](@ref).
"""
function genrhsfun(r::DynamicRule, mod::Module)
    params = Expr(:tuple, :_lhs_expr, :_subst, :_egraph, r.patvars...)
    ex = :($params -> $(r.right))
    closure_generator(mod, ex)
end
