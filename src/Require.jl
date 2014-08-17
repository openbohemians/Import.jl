module Require

export @require

function resolve(path::String, base::String)
	path[1] == '/' && return complete(path)
	ismatch(r"^\.+/?", path) && return complete(joinpath(base, path))
	search(path, base)
end

function complete(path::String)
	for p in completions(path)
		ispath(p) && return p
	end
	error("$path can not be completed to a real file")
end

function search(path::String, base::String)
	for p in completions(path)
		p = "$base/deps/$p"
		ispath(p) && return p
	end
	@assert(base != "/", "$path not installed")
	search(path, dirname(base))
end

function completions(path::String)
	# already complete
	ismatch(r"\.jl$", path) && return [path]
	# explicitly a dir
	ismatch(r"\/$", path) && return ["$(path)index.jl"]
	# could be a file or a dir
	["$(path).jl", "$(path)/index.jl"]
end

cache = Dict{String,Module}()

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

entry = ""
set_entry(path::String) = global entry = path

function require(path::String; locals...)
	base = dirname(string(module_name(current_module())))
	if isempty(base) base = entry end
	require(path, base; locals...)
end

macro require(path::String, names...)
	req = :(begin m = require($path) end)
	names = [x for x in names] # make array
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

end # module
