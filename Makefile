w:= $(shell echo $(workspace))

docs:
ifdef w
	jazzy -x -workspace,$(w),-scheme,Podest --min-acl internal
else
	@echo "Which workspace?"
endif

.PHONY: clean
clean:
	rm -rf docs
