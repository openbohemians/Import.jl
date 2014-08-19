module Import

  export encap, @imports

  # The import macro makes avaialable exported references from an external
  # module-file. Imported module-files are cached, so if another module has 
  # already imported it, the same module object will be returned from the cache.
  # Otherwise the file's code will be wrapped in an implicit module scope,
  # evaluated and added to the cache.
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
  # the module-file are imported.
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
  # syntax.
  # 
  #     @import "http" get => fetch
  #     @assert fetch == @import("http").get
  #
  # An optional `:` can be placed after the module-file name and before the
  # specific names.
  #
  #     @import "http" : get => fetch
  #
  # If you wish to import a module-file whole-clothe and give it a handle, use:
  #
  #     @import "Http" => http
  #
  # Then the module-file can be used as such:
  #
  #     http.get(...)
  #     http.post(...)
  #
  # Alternatively assignment can be used with the underlying encapsulating
  # function.
  #
  #     http = encap("Http")
  #
  # TODO: Is encap a good name, I shy away from import so not to imply that exports are bing added.
  #
  # TODO: I think we should require commas betweenthe names. e.g. `@import "foo": a, b=>x, c`
  # 
  # TODO: Assigned modules, e.g. `Foo = @import foo` is that possible ?
  #
  macro imports(names...)
	  names = [x for x in names] # make array

    path = shift!(names)

	  req = :(begin m = encap($path) end)

	  # default to importing everything
	  if isempty(names)
		  m = encap(path)
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

  #
  cache = Dict{String,Module}()

  #
  entry = ""

  #
  set_entry(path::String) = global entry = path


  # Encapsulate a file as a module. Supports parametric encapsulation.
  function encap(path::String; locals...)
	  base = dirname(string(module_name(current_module())))
	  if isempty(base)
      base = entry 
    end
	  encap(path, base; locals...)
  end

  #
  function encap(path::String, base::String; locals...)
	  name = realpath(resolve(path, base))
	  haskey(cache, name) && return cache[name]
	  sym = symbol(name)
	  ast = Expr(:module, true, sym, parse("""begin
		  using Import
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
    if isabsolute(path)
      goodpath(meldpath(path))
    elseif isrelative(path)
      goodpath(meldpath(base, path))
    else
      goodpath(pkgpath(path))
    end
  end

  # Meld path join base and path and adds `.jl` extension if needed.
  function meldpath(base, path)
    frnt, ext = splitext(path)
    if ext == ""
      path = "$path.jl"
    end
    return joinpath(base, path)
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
	  beginswith(path, "/") || beginswith(path, "~/")
  end

  # Is a path relative? Relative paths begin with `./` or `../`.
  function isrelative(path::String)
	  ismatch(r"^\.+/?", path)
  end

  # Resolve package path.
  function pkgpath(path::String)
    parts = split(path, '/')

    name = parts[1]
    if length(parts) > 1
      rest = joinpath(parts[2:end]...)
    else
      rest = name
    end

    if Pkg.installed(name)
      return realpath(joinpath(Pkg.dir(name), "$(rest).jl"))
    else
      error("$name is not a package")
    end
  end

  # Return file path if found, otherwise report error.
  function goodpath(path)
    if ispath(path)
      return realpath(path)
    else
      error("$path can not be resolved to a real file")
    end
  end

end
