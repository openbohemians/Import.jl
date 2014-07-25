
install:
	@ln -fs $$PWD `julia -e "Pkg.init();print(Pkg.dir())"`/Require
	@julia -e 'Pkg.resolve()'

test: install
	@julia test/runtests.jl

.PHONY: install test
