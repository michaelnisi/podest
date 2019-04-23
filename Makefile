# Makefile - A minimal makefile for Podest

w := $(shell echo $(workspace))
scheme := Podest

docs:
ifdef w
	jazzy -x -workspace,$(w),-scheme,$(scheme) \
		--min-acl internal \
		--author "Michael Nisi" \
		--author_url https://troubled.pro
else
	@echo "Which workspace?"
endif

.PHONY: clean
clean:
	rm -rf docs
