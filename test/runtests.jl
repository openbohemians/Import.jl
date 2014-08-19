import Import: encap, @imports

using Base.Test

a = encap("./a/index")

@test isa(a, Module)
@test a.a == 1
@test a.b == 2
@test a.c == 3

b = encap("./b")

@test isa(b, Module)
@test b.a == "hi"

ab = encap("./a/b")

@test isa(ab, Module)
@test ab.a == "secret"

@test is(encap("./a/b"), encap("./a/b"))
@test is(encap("./a/c").a, encap("./a/b"))
@test is(encap("./c").a, encap("./b"))

@test_throws ErrorException encap("casper")




# locals

locals = encap("./locals"; a=1, b=2)
@test locals.a == 1
@test locals.b == 2

# legacy modules

old = import("./old")
@test old.one == 1

