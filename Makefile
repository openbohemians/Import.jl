
install:
	@ln -fs $$PWD `julia -e 'print(Pkg.dir("Require"))'`

test:
	@julia test/runtests.jl

.PHONY: install test
