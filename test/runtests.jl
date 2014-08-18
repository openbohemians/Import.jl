import Import: load, @inport

using Base.Test

a = load("./a/index")

@test isa(a, Module)
@test a.a == 1
@test a.b == 2
@test a.c == 3

b = load("./b")

@test isa(b, Module)
@test b.a == "hi"

ab = load("./a/b")

@test isa(ab, Module)
@test ab.a == "secret"

@test is(load("./a/b"), load("./a/b"))
@test is(load("./a/c").a, load("./a/b"))
@test is(load("./c").a, load("./b"))

@test_throws ErrorException load("casper")


# macro

@inport "a"
@test a == 1
@test b == 2
@test_throws UndefVarError c

@inport "a" a b c
@test a == 1
@test b == 2
@test c == 3

# aliasing

@inport "a" a => f b c
@test f == 1
@inport "a" a=>f b=>g c=>h
@test f == 1
@test g == 2
@test h == 3

@inport "eval"


# locals

locals = load("locals"; a=1, b=2)
@test locals.a == 1
@test locals.b == 2

# legacy modules

old = import("old")
@test old.one == 1

