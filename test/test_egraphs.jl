
# ENV["JULIA_DEBUG"] = Metatheory


## SPAZZATURA

@testset "Merging" begin
    testexpr = :((a * 2)/2)
    testmatch = :(a << 1)
    G = EGraph(testexpr)
    t2 = addexpr!(G, testmatch)
    merge!(G, t2.id, 3)
    @test in_same_set(G.uf, t2.id, 3) == true
    # DOES NOT UPWARD MERGE
end

#testexpr = :(42a + b * (foo($(Dict(:x => 2)), 42)))

@testset "Simple congruence - rebuilding" begin
    testexpr = :(f(a,b) + f(a,c))
    G = EGraph(testexpr)
    t1 = addexpr!(G, :b)

    t2 = addexpr!(G, :c)
    # display(G.emap); println()

    c_id = merge!(G, t2.id, t1.id)
    # display(G.emap); println()
    @test in_same_set(G.uf, c_id, t1.id)
    @test in_same_set(G.uf, t2.id, t1.id)
    # println(find_root!(G.uf, t2.id))
    @test find_root!(G.uf, t2.id) == 4
    rebuild!(G)
    # f(a,b) = f(a,c)
    # display(G.emap); println()
    # display(G.hashcons); println()
    # display(G.parents); println()


    @test in_same_set(G.uf, 5, 3)
end


@testset "Simple nested congruence" begin
    apply(n, f, x) = n == 0 ? x : apply(n-1,f,f(x))
    f(x) = Expr(:call, :f, x)

    G = EGraph(:a)

    t1 = addexpr!(G, apply(6, f, :a))
    t2 = addexpr!(G, apply(9, f, :a))

    c_id = merge!(G, t1.id, 1) # a == apply(6,f,a)
    c2_id = merge!(G, t2.id, 1) # a == apply(9,f,a)

    # display(G.emap); println()

    rebuild!(G)

    # display(G.emap); println()

    t3 = addexpr!(G, apply(3, f, :a))
    t4 = addexpr!(G, apply(7, f, :a))

    # f^m(a) = a = f^n(a) ⟹ f^(gcd(m,n))(a) = a
    @test in_same_set(G.uf, t1.id, 1) == true
    @test in_same_set(G.uf, t2.id, 1) == true
    @test in_same_set(G.uf, t3.id, 1) == true
    @test in_same_set(G.uf, t4.id, 1) == false

    # if m or n is prime, f(a) = a
    t5 = addexpr!(G, apply(11, f, :a))
    t6 = addexpr!(G, apply(1, f, :a))
    c5_id = merge!(G, t5.id, 1) # a == apply(11,f,a)

    rebuild!(G)

    @test in_same_set(G.uf, t5.id, 1) == true
    @test in_same_set(G.uf, t6.id, 1) == true
end
