.PHONY: compile getDependencies test default

getDependencies:
	$(info Getting Dependencies...)
	mix deps.get

compile:
	$(info Compiling code...)
	mix compile

test:
	$(info Running tests...)
	mix test

default: getDependencies compile test
