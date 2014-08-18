module Import

  export @import

  # The import macro imports exported references from a external module-file.
  # Imported module-files are cached, so if another module has already imported
  # it, the same module object will be returned from the cache. Otherwise the
  # file's code will be wrapped in an implicit module scope, evaluated and
  # added to the cache.
  #
  # To to import a module-file from a package simply pass `@import` the package
  # name undecorated, e.g. `@import Foo`. This will look for a file by the name
  # of `Foo.jl` in the package `Foo`.
  #
  # To import a local module-file by name pass `@import` the name prefixed by
  # `./`, e.g. `@import ./foo`. The name is converted to a file path by adding
  # a `.jl` extension and searched for in the *local directory*, the same location
  # as the file doing the importing.
  #
  # It is possible to import module-files using any of the Unix pathname conventions.
  # To import from an absolute file system path, prefix a slash to the front of
  # the path name, e.g. `@import /a/file`. To import from a parent directory
  # relative to importing file use the `../` prefix, and from the current users
  # home directory use `~/`.
  # 
  # All of the paths can be placed in quotes, e.g. `@import "foo"` and will work the
  # same as above. The quotes can be useful though to create dynamic lookups using
  # variable substitution, e.g. `@import "$var"`.
  # 
  # Also the `.jl` extension can be given, e.g. `@import foo.jl`. It has no effect
  # on behavior.
  #
  # When a module-file is imported, by default all *exported* variables from
  # are imported.
  # 
  #     @import "http"
  #     @assert get == @import("http").get
  #
  # But its also easy to pull in just the variables you want.
  # 
  #     @import "http" get post
  #     @assert get == @import("http").get
  #     @assert post == @import("http").post
  #
  # To rename variables as they are imported you can use the `name => new_name`
  # syntax
  # 
  #     @import "http" get => fetch
  #     @assert fetch == @import("http").get
  #
  # TODO: Use `:` after module name when selecting specific imports ?
  #
  # TODO: Assigned modules, e.g. `Foo = @import foo`.
  #
  macro require(names...)
	  names = [x for x in names] # make array

    path = shift!(names)

	  req = :(begin m = require($path) end)

	  # default to importing everything
	  if isempty(names)
		  m = require(path)
		  names = Base.names(m)
		  m = module_name(m)
		  filter!(n -> m != n, names)
	  end

	  for n in names
		  if isa(n, Expr)
			  if n.head == :macrocall
				  append!(names, n.args)
			  else
				  @assert n.head == symbol("=>")
				  push!(req.args, :($(esc(n.args[2])) = m.$(n.args[1])))
			  end
		  else
			  @assert isa(n, Symbol)
			  push!(req.args, :($(esc(n)) = m.$n))
		  end
	  end

	  push!(req.args, :m)

	  req
  end

  entry = ""
  set_entry(path::String) = global entry = path

  #
  function require(path::String; locals...)
	  base = dirname(string(module_name(current_module())))
	  if isempty(base)
      base = entry 
    end
	  require(path, base; locals...)
  end

  cache = Dict{String,Module}()

  #
  function require(path::String, base::String; locals...)
	  name = realpath(resolve(path, base))
	  haskey(cache, name) && return cache[name]
	  sym = symbol(name)
	  ast = Expr(:module, true, sym, parse("""begin
		  using Require
		  eval(e) = Base.eval(current_module(), e)
		  $(readall(name))
	  end"""))
	  body = ast.args[3].args
	  # lift module wrapper so standard modules can be loaded
	  if length(body) == 6 && body[6].head == :module
		  splice!(body, 6, body[6].args[3].args)
	  end
	  # define locals
	  for (key,value) in locals
		  unshift!(body, :(const $key = $value))
	  end
	  eval(ast)
	  cache[name] = eval(sym)
  end

  # Resolve a load path.
  function resolve(path::String, base::String)
    if isabolsute(path)
      goodpath(meldpath(path))
    elseif isrelative(path)
      goodpath(meldpath(base, path))
    else
      goodpath(package(path, base))
    end
  end

  # Meld path join base and path and adds `.jl` extension if needed.
  function meldpath(base, path)
    frnt, ext = splitext(path)
    if ext == ""
      path = "$path.jl"
    end
    return realpath(joinpath(base, path))
  end

  # Meld path adds `.jl` extension if needed.
  function meldpath(path)
    frnt, ext = splitext(path)
    if ext == ""
      path = "$path.jl"
    end
    return realpath(path)
  end

  # Is a path absolute? Absolute paths start with `/` or `~/`.
  function isabsolute(path::String)
	  startwith(path, '/') || startwith(path, '~/')
  end

  # Is a path relative? Relative paths begin with `./` or `../`.
  function isrelative(path::String)
	  ismatch(r"^\.+/?", path)
  end

  # Resolve package path.
  function package(path::String, base::String)
    m = match(r"^(\w*)[\](.*)$", path)

    name = m.captures[1]
    rest = m.captures[2]

    if isempty(rest)
      rest = name
    end

    if Pkg.installed(name)
      return realpath(joinpath(Pkg.dir(name), "$(rest).jl"))
    else
      error("$name is not a package)
    end
  end

  # Return file path if found, otherwise report error.
  function goodpath(path)
    if ispath(file)
      return file
    else
      error("$file can not be resolved to a real file")
    end
  end

end
