module Require

  export @require

  # Load a "modile" -- a module-file. If another module has already required it
  # the same module object will be returned from the cache. Otherwise it will
  # be wrapped in an implicit module scope, evaluated and added to the cache.
  #
  # There are four kinds of paths you can pass to @require.
  #
  # * Absolute path, e.g. `@require /a/file.jl`. 
  #
  # * Relative path, e.g. `@require ./sibling` or `@require ../aunty`. These paths
  #   are resolved relative to the file making the call to @require.
  #
  # * Package path, e.g. "@require Foo!". This notation explicitly looks for
  #   file `Foo.jl` in package Foo.
  #
  # * Plain name, e.g. `@require foo`. This is the most useful. It will
  #   first look in the local directory for a matching `foo.jl`, if not found 
  #   there it will look for the same file in package "foo" (though in that case
  #   it is usually "Foo").
  # 
  # All of the paths can be placed in quotes, e.g. `@require "foo"` is the same
  # as above.
  #
  # By default all exported variables from a module are imported.
  # 
  #     @require "http"
  #     @assert get == @require("http").get
  #
  # But its also easy to pull in just the variables you want.
  # 
  #     @require "http" get post
  #     @assert get == @require("http").get
  #     @assert post == @require("http").post
  #
  # To rename variables as they are imported you can use the their_name => your_name syntax
  # 
  #     @require "http" get => fetch
  #     @assert fetch == @require("http").get
  #
  #
  # TODO: Better package notation ?
  #
  # TODO: Use `:` after module name when selecting specific imports ?
  #
  # TODO: Assigned modules, e.g. `Foo = @require foo`.
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

  # Attempt to resolve a load path.
  #
  # TODO: My god there has to be a better way to write this.
  function resolve(path::String, base::String)
	  p = absolute(path, base)
    if p != false
      return p 
    end

    p = relative(path, base)
    if p != false
      return p
    end

    p = locals(path, base)
    if p != false 
      return p
    end

    #p = vendor(path, base)
    #if p != false 
    #  return p
    #end

    p = package(path, base)
    if p != false
      return p
    end

    error("$path can not be resolved to a real file")
  end

  #
  function absolute(path::String, base::String)
	  if path[1] == '/'
      return path
    else
    	if endswith(path, "!")
        return package(path.chomp("!"))
      end
    end
    return false
  end

  #
  function relative(path::String, base::String)
	  ismatch(r"^\.+/?", path) && return joinpath(base, path)
  end

  # Local path.
  function locals(path::String, base::String)
	  # for p in completions(path)
	  # 	ispath(p) && return p
	  # end
    fullpath = "$(joinpath(base, path)).jl"
    ispath(fullpath) && return fullpath
  end

  ## Vendored dependency.
  ##
  ## TODO: This needs to stop moving up wihen it hits the project root.
  #function vendor(path::String, base::String)
  #	for p in completions(path)
  #		p = "$base/deps/$p"
  #		ispath(p) && return p
  #	end
  #	base == "/" && return false
  #	vendor(path, dirname(base))
  #end

  #
  function package(path::String, base::String)
    if Pkg.installed(path)
      fpath = joinpath(Pkg.dir(path), "$(path).jl")
      if ispath(fpath)
        return path
      end
    end
    return false
  end

end # module
