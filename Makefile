w:= $(shell echo $(workspace))

docs:
ifdef w
	jazzy -x -workspace,$(w),-scheme,Podest \
		--min-acl internal \
		--author "Michael Nisi" \
		--author_url https://troubled.pro
else
	@echo "Which workspace?"
endif

.PHONY: clean
clean:
	rm -rf docs
