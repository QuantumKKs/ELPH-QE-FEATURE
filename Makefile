sinclude ../make.inc

.PHONY: all clean

all:
	( cd src ; $(MAKE) all || exit 1 )

clean:
	( cd src ; $(MAKE) clean )
