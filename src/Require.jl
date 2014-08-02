module Require

function resolve(path::String, base::String)
	path[1] == '/' && return complete(path)
	ismatch(r"^\.+/", path) && return complete(joinpath(base, path))
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
		p = "$base/dependencies/$p"
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

function require(path::String, base::String)
	name = realpath(resolve(path, base))
	haskey(cache, name) && return cache[name]
	sym = symbol(name)
	ast = Expr(:module, true, sym, parse("""begin
		import Require: @require, require
		$(readall(name))
	end"""))
	eval(ast)
	cache[name] = eval(sym)
end

function require(path::String)
	base = dirname(string(current_module())[9:end])
	if isempty(base)
		base = isinteractive() ? pwd() : dirname(@__FILE__())
	end
	require(path, base)
end

macro require(path::String, names...)
	req = :(require($path))
	isempty(names) && return req
	req = :(begin m = $req end)
	for n in names
		if isa(n, Expr)
			@assert n.head == symbol("=>")
			push!(req.args, :($(esc(n.args[2])) = m.$(n.args[1])))
		else
			@assert isa(n, Symbol)
			push!(req.args, :($(esc(n)) = m.$n))
		end
	end
	push!(req.args, :m)
	req
end

end # module
