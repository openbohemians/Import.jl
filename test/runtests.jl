import Require: require, @require
using Base.Test

a = require("a")

@test isa(a, Module)
@test a.a == 1
@test a.b == 2
@test a.c == 3

b = require("b")

@test isa(b, Module)
@test b.a == "hi"

ab = require("a/b")

@test isa(ab, Module)
@test ab.a == "secret"

@test is(require("a/b"), require("a/b"))
@test is(require("a/c").a, require("a/b"))
@test is(require("c").a, require("b"))

@test_throws ErrorException require("casper")

# macro

@require "a"
@test a == 1
@test b == 2
@test_throws UndefVarError c

@require "a" a b c
@test a == 1
@test b == 2
@test c == 3

# aliasing

@require "a" a => f b c
@test f == 1
@require "a" a=>f b=>g c=>h
@test f == 1
@test g == 2
@test h == 3

@require "eval"
