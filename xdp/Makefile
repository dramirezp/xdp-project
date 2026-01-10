CLANG ?= clang
LLC ?= llc
ARCH := $(shell uname -m | sed 's/x86_64/x86/' | sed 's/aarch64/arm64/')

all: xdp_filter.o

xdp_filter.o: xdp_filter.c
	$(CLANG) -O2 -g -target bpf -D__TARGET_ARCH_$(ARCH) \
		-I/usr/include/$(shell uname -m)-linux-gnu \
		-c $< -o $@

clean:
	rm -f *.o

.PHONY: all clean