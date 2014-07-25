
# Require

A better module system for Julia inspired by node's.

## Installation

```sh
git clone https://github.com/jkroso/Require.jl.git `julia -e 'print(Pkg.dir())'`/Require
```

Then in the entry file to your app:

```julia
import Require.require
```

## API

### require(path::String)

Load a file as a module. If another module has already required the file `path` refers to the same module object will be returned from the cache. Otherwise it will be wrapped in an implicit module scope and evaluated. There are three kinds of `path`s you can pass to `require`:

- Absolute path e.g "/a/file.jl"
- Relative path: e.g. "./sibling", "../aunty". These paths are resolved relative to the file making the call to `require`
- Module path: e.g. "Http", "Graphics". These are like relative paths except instead of looking directly in the calling files directory it looks inside a special folder named "dependencies". This provides a nice place to install the 3rd party dependencies your module requires. e.g if "/a/file.jl" was to `require` "Http" the first place the system would check is "/a/dependencies/Http". If it doesn't find anything there it recurs up a directory and tries again until it reaches the top level directory. If it can't find a match it throws an error.
