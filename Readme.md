
# Require

A better module system for Julia inspired by node's. Julia's built in module system is OK mechanically but lacks some nice ideas from node. Firstly installing one module should never affect another. Julia uses one name-space for all its modules and uses one install folder so _all_ modules used within your app must have unique names which is not scalable and winds up discouraging innovation in the public domain. Node actually made the name-spacing mistake too but still had huge success thanks to getting the latter correct. Another thing node gets right is they wrap each file in an implicit module. Where as in Julia files are essentially meaningless; modules are named explicitly and within the code. This means that when you fork a project you have to change its name to avoid conflicts with the original. Nodes implicit module naming makes naming conflicts impossible.

## Installation

```sh
git clone https://github.com/jkroso/Require.jl.git `julia -e 'print(Pkg.dir())'`/Require
```

Then in your "~/.juliarc.jl" add:

```julia
using Require
if isinteractive()
  Require.set_entry(pwd())
else
  Require.set_entry(dirname(realpath(joinpath(pwd(), ARGS[1]))))
end
```

## API

### @require(path::String, [names...])

Load a file as a module. If another module has already required the file `path` refers to the same module object will be returned from the cache. Otherwise it will be wrapped in an implicit module scope and evaluated. There are three kinds of `path`s you can pass to `@require`:

- Absolute path e.g "/a/file.jl"
- Relative path: e.g. "./sibling", "../aunty". These paths are resolved relative to the file making the call to `@require`
- Module path: e.g. "Http", "Graphics". These are like relative paths except instead of looking directly in the calling files directory it looks inside a special folder named "dependencies". This provides a nice place to install the 3rd party dependencies your module requires. e.g if "/a/file.jl" was to `@require "Http"` the first place the system would check is `"/a/dependencies/Http"`. If it doesn't find anything there it recurs up a directory and tries again until it reaches the top level directory. If it can't find a match it throws an error

By default all exported variables from a module are imported

```julia
@require "http"
@assert get == @require("http").get
```

But its also easy to pull in just the variables you want

```julia
@require "http" get post
@assert get == @require("http").get
@assert post == @require("http").post
```

To rename variables as they are imported you can use the `their_name => your_name` syntax

```julia
@require "http" get => fetch
@assert fetch == @require("http").get
```

### require(path::String; locals...)

Extending the global context isn't really possible in julia however its occasionally useful for creating DSLish things like test runners. The `require` function makes it possible to define variables within a module

```julia
Require.require("./mytests"; test=Base.Test.do_test)
```

If you want to define macros thats a little complicated due to syntax problems but still possible

```julia
using Base.Test
Require.require("./mytests"; [
  symbol("@test") => eval(symbol("@test"))
]...)
```
