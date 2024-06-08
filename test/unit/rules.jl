using Metatheory, Test

@testset "Fully Qualified Function names" begin
  r = @rule Main.identity(~a) --> ~a

  @test operation(r.left) == identity
  @test r.right == PatVar(:a, 1)

  expr = :(Main.test(11, 12))
  rule = @rule Main.test(~a, ~b) --> ~b
  @test rule(expr) == 12
end

@testset begin
  r = @rule f(~x) --> ~x

  @test isempty(r.name)

  r = @rule "totti" f(~x) --> ~x
  @test r.name == "totti"
  @test operation(r.left) == :f
  @test arguments(r.left) == [PatVar(:x, 1)]
  @test r.right == PatVar(:x, 1)
end