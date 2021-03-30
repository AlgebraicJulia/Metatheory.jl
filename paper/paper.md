---
title: 'Metatheory.jl: Fast and Elegant Algebraic Computation in Julia with Extensible Equality Saturation'
tags:
  - Julia
  - compiler
  - symbolic
  - algebra
  - rewriting
  - optimization
authors:
  - name: Alessandro Cheli #^[Custom footnotes for e.g. denoting who the corresponding author is can be included like this.]
    orcid: 0000-0002-8122-9469
    affiliation: 1 # (Multiple affiliations must be quoted)
affiliations:
 - name: University of Pisa, Pisa, Italy
   index: 1
date: 11 February 2021
bibliography: paper.bib

---

# Statement of Need

<!-- The Julia programming language is a fresh approach to technical computing [@bezanson2017julia], disrupting the popular conviction that a programming language cannot be very high level, easy to learn, and performant at the same time. One of the most practical features of Julia is the excellent metaprogramming and macro system, allowing for programmatic generation and manipulation of Julia expressions as first-class values in the core language, with a well-known paradigm similar to LISP idioms such as Scheme,
a programming language property colloquially referred to as *homoiconicity*. -->

The Julia programming language is a fresh approach to technical computing [@bezanson2017julia], disrupting the popular conviction that a programming language cannot be high-level, easy to learn, and performant at the same time. One of the most practical features of Julia is the excellent metaprogramming and macro system, allowing for *homoiconicity*: programmatic generation and manipulation of expressions as first-class values, a well-known paradigm found in LISP dialects such as Scheme.

Metatheory.jl is a general-purpose metaprogramming and algebraic computation library for the Julia programming language, designed to take advantage of its powerful reflection capabilities to bridge the gap between symbolic mathematics,
abstract interpretation, equational reasoning, optimization, composable compiler transforms, and advanced homoiconic pattern-matching features. Intuitively, Metatheory.jl transforms Julia expressions into other Julia expressions at both compile time and run time. This allows users to perform customized and composable compiler optimizations that are specifically tailored to single, arbitrary Julia packages. The library provides a simple, algebraically composable interface to help scientists to implement and reason about all kinds of formal systems, by defining concise rewriting rules as syntactically-valid Julia code. The primary benefit of using Metatheory.jl is the algebraic nature of the specification of the rewriting system. Composable blocks of rewrite rules bear a strong resemblance to algebraic
structures encountered in everyday scientific literature.

<!-- Rewrite rules are defined as regular Julia expressions, manipulating other syntactically valid Julia expressions: since Julia supports LaTeX-like abbreviations of UTF8 mathematical symbols as valid operators and symbols,
rewrite theories in Metatheory.jl can bear a strong structural and visual resemblance to mathematical formalisms encountered in paper literature. -->

<!-- Theories can then be executed through two, highly composable, rewriting backends. The first backend relies on a *classic* fixed-point recursive iteration of AST, with a match-and-replace algorithm built on top of the [@matchcore] pattern matcher. This backend is suitable for deterministic recursive algorithms that intensively use pattern matching on syntax trees, for example, defining an interpreter from operational or denotational semantics. Nevertheless, when using this classical approach, even trivial equational rules such as commutativity and associativity may cause the rewriting algorithm to loop indefinitely, or to return unexpected results. This is known as *rewrite order* and is notoriously recognized for requiring extensive user reasoning about the ordering and structuring of rules to ensure termination. -->

# Summary

Metatheory.jl offers a concise macro system to define *theories*: composable blocks of rewriting rules that can be executed through two, highly composable, rewriting backends. The first is based on standard rewriting, built on top of the pattern matcher developed in @matchcore.
This approach, however, suffers from the usual problems of rewriting systems. For example, even trivial equational rules such as commutativity may lead to non-terminating systems and thus need to be adjusted by some sort of structuring or rewriting order, which is known to require extensive user reasoning.


The other back-end for Metatheory.jl, the core of our contribution, is designed so that it does not require the user to reason about rewriting order. To do so it relies on equality saturation on *e-graphs*, the state-of-the-art technique adapted from the `egg` Rust library [@egg].

*E-graphs* can compactly represent many equivalent expressions and programs. Provided with a theory of rewriting rules, defined in pure Julia, the *equality saturation* process iteratively executes an e-graph-specific pattern matcher and inserts the matched substitutions. Since e-graphs can contain loops, infinite derivations can be represented compactly and it is not required that the described rewrite system be terminating or confluent.

The saturation process relies on the definition of e-graphs to include *rebuilding*, i.e. the automatic process of propagation and maintenance of congruence closures.
One of the core contributions of @egg is a delayed e-graph rebuilding process that is executed at the end of each saturation step, whereas previous definitions of e-graphs in the literature included rebuilding after every rewrite operation.
Provided with *equality saturation*, users can efficiently derive (and analyze) all possible equivalent expressions contained in an e-graph. The saturation process can be required to stop prematurely as soon as chosen properties about the e-graph and its expressions are proved. This latter back-end based on *e-graphs* is suitable for partial evaluators, symbolic mathematics, static analysis, theorem proving and superoptimizers.

<!-- The other back-end for Metatheory.jl, the core of our contribution, is designed to not require the user to reason about rewriting order by employing equality saturation on e-graphs. This backend allows programmers to define equational theories in pure Julia without worrying about rule ordering and structuring, by relying on state-of-the-art techniques for equality saturation over *e-graphs* adapted from the `egg` Rust library [@egg].
Provided with a theory of equational rewriting rules, *e-graphs* compactly represent many equivalent programs. Saturation iteratively executes an e-graph specific pattern matcher to efficiently compute (and analyze) all possible equivalent expressions contained in the e-graph congruence closure. This latter back-end is suitable for partial evaluators, symbolic mathematics, static analysis, theorem proving and superoptimizers. -->

![These four e-graphs represent the process of equality saturation, adding many equivalent ways to write $a * (2 * 3) / 6$ after each iteration. \label{fig:egraph}](egraphs.png)


The original `egg` library [@egg] is
the first implementation of generic and extensible e-graphs [@nelson1980fast]; the contributions of `egg` include novel amortized algorithms for fast and efficient equivalence saturation and analysis.
Differently from the original Rust implementation of `egg`, which handles expressions defined as Rust strings and data structures, our system directly manipulates homoiconic Julia expressions, and can therefore fully leverage the Julia subtyping mechanism [@zappa2018julia], allowing programmers to build expressions containing not only symbols but all kinds of Julia values.
This permits rewriting and analyses to be efficiently based on runtime data contained in expressions. Most importantly, users can -- and are encouraged to -- include type assertions in the left-hand side of rewriting rules in theories.

One of the project goals of Metatheory.jl, beyond being easy to use and composable, is to be fast and efficient. Both the first-class pattern matching system and the generation of e-graph analyses from theories rely on RuntimeGeneratedFunctions.jl [@rgf], generating callable functions at runtime that efficiently bypass Julia's world age problem (explained and formalized in @belyakova2020world) with the full performance of a standard Julia anonymous function.


## Analyses and Extraction

With Metatheory.jl, modeling analyses and conditional/dynamic rewrites are straightforward. It is possible to check conditions on runtime values or to read and write from external data structures during rewriting. The analysis mechanism described in `egg` [@egg] and re-implemented in our contribution lets users define ways to compute additional analysis metadata from an arbitrary semi-lattice domain, such as costs of nodes or logical statements attached to terms. Other than for inspection, analysis data can be used to modify expressions in the e-graph both during rewriting steps and after e-graph saturation.

Therefore using the equality saturation (e-graph) backend, extraction can be performed as an on-the-fly e-graph analysis or after saturation. Users
can define their own cost function, or choose between a variety of predefined cost functions for automatically extracting the best-fitting expressions from an equivalence class represented in an e-graph.

# Example Usage

In this example, we build rewrite systems, called `theories` in Metatheory.jl, for simplifying expressions
in the usual commutative monoid of multiplication and the commutative group of addition, and we compose
the `theories` together with a *constant folding* theory. The pattern matcher for the e-graphs backend
allows us to use the existing Julia type hierarchy for integers and floating-point numbers with a high level
of abstraction. As a contribution over the original egg [@egg] implementation, left-hand sides of rules in Metatheory.jl can contain type assertions on pattern variables, to give rules that depend on consistent type hierarchies and  to seamlessly access literal Julia values in the right-hand side of dynamic rules.

We finally introduce two simple rules for simplifying fractions, that
for the sake of simplicity, do not check any additional analysis data.
\autoref{fig:egraph} contains a friendly visualization of a consistent fragment of the equality saturation process in this example.
You can see how loops evidently appear in the definition of the rewriting rules.
While the classic rewriting backend would loop indefinitely or stop early when repeatedly matching these rules,
the e-graph backend natively supports this level of abstraction and allows the
programmer to completely forget about the ordering and looping of rules.
Efficient scheduling heuristics are applied automatically to prevent instantaneous
combinatorial explosion of the e-graph, thus preventing substantial slowdown of the equality saturation
process.

```julia
using Metatheory
using Metatheory.EGraphs

comm_monoid = @theory begin
  # commutativity
  a * b => b * a
  # identity
  a * 1 => a
  # associativity
  a * (b * c) => (a * b) * c
  (a * b) * c => a * (b * c)
end;

comm_group = @theory begin
  # commutativity
  a + b => b + a
  # identity
  a + 0 => a
  # associativity
  a + (b + c) => (a + b) + c
  (a + b) + c => a + (b + c)
  # inverse
  a + (-a) => 0
end;

# dynamic rules are defined with the `|>` operator
folder = @theory begin
  a::Real + b::Real |> a+b
  a::Real * b::Real |> a*b
end;

div_sim = @theory begin
  (a * b) / c => a * (b / c)
  a::Real / a::Real  |>  (a != 0 ? 1 : error("division by 0"))
end;

t = union(comm_monoid, comm_group, folder, div_sim) ;

g = EGraph(:(a * (2*3) / 6)) ;
saturate!(g, t) ;
ex = extract!(g, astsize)
# :a

```

# Conclusion

Many applications of equality saturation to advanced optimization tasks have been recently published. Herbie [@panchekha2015automatically]
is a tool for automatically improving the precision of floating point expressions, which recently switched to `egg` as the core rewriting backend. However, Herbie requires interoperation and conversion of expressions between different languages and libraries. In @yang2021equality, the authors used `egg` to superoptimize tensor signal flow graphs describing neural networks.  Implementing similar case studies in pure Julia would make valid research contributions on their own. We are confident that a well-integrated and homoiconic equality saturation engine in pure Julia will permit exploration of many new metaprogramming applications, and allow them to be implemented in an elegant, performant and concise way. Code for Metatheory.jl is available in @metatheory, or at [https://github.com/0x0f0f0f/Metatheory.jl](https://github.com/0x0f0f0f/Metatheory.jl).

# Acknowledgements

We acknowledge Max Willsey and contributors for their work on the original `egg` library [@egg], Christopher Rackauckas and Christopher Foster for their efforts in developing RuntimeGeneratedFunctions [@rgf], Taine Zhao for developing MLStyle [@mlstyle] and MatchCore [@matchcore], and Philip Zucker for his original idea of implementing E-Graphs in Julia [@philzuck1; @philzuck2] and support during the development of the project. Special thanks to Filippo Bonchi for a friendly review of a preliminary version of this article.

# References
