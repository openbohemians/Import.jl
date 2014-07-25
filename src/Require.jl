module Require

function resolve(path::String, base::String)
	path[1] == '/' && return complete(path)
	ismatch(r"^\.+/", path) && return complete(joinpath(base, path))
	search(path, base)
end

function complete(path::String)
	for p in completions(path)
		if ispath(p) return p end
	end
	error("$path can not be completed to a real file")
end

function search(path::String, base::String)
	dir = base
	while true
		paths = map(completions(path)) do x
			"$dir/dependencies/$x"
		end
		for p in paths
			if ispath(p) return p end
		end
		@assert(dir != "/", "$path not installed in $base")
		dir = dirname(dir)
	end
end

function completions(path::String)
	# Did they end it without an extension
	if ismatch(r"\.jl$", path) return [path] end
	# Is it an explicit directory
	if ismatch(r"\/$", path) return ["$(path)index.jl"] end
	["$(path).jl", "$(path)/index.jl"]
end

cache = Dict{String,Module}()

function require(path::String, base::String)
	name = realpath(resolve(path, base))
	haskey(cache, name) && return cache[name]
	sym = symbol("_" * string(gensym())[3:end])
	ast = parse("""module $sym
		import Require
		require(path::String) = Require.require(path, "$(dirname(name))")
		$(readall(name))
	end""")
	eval(ast)
	cache[name] = eval(sym)
end

function require(path::String)
	require(path, dirname(@__FILE__()))
end

end # module
