# Test import macro

import Import: encap, @imports

using Base.Test

@imports "./a/index"
@test a == 1
@test b == 2
@test_throws UndefVarError c

@imports "./a/index" a b c
@test a == 1
@test b == 2
@test c == 3

# aliasing

@imports "./a/index" a => f b c
@test f == 1
@imports "./a" a=>f b=>g c=>h
@test f == 1
@test g == 2
@test h == 3

@imports "eval"

