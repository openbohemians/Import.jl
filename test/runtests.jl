import Require.require

a = require("a")

@assert isa(a, Module)
@assert a.a == 1
@assert a.b == 2
@assert a.c == 3

b = require("b")

@assert isa(b, Module)
@assert b.a == "hi"

ab = require("a/b")

@assert isa(ab, Module)
@assert ab.a == "secret"

@assert is(require("a/b"), require("a/b"))

@assert is(require("a/c").a, require("a/b"))

@assert is(require("c").a, require("b"))
