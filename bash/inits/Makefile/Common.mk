# vim: ts=4 list

# ------------------------------------------------------------------------
# Set all compilation targets in TARGETS
# And default target in TARGET
#
# Set appropriate rules for each of them, e.g.:
# ------------------------------------------------------------------------
# TARGETS = target1 target2
# TARGET ?= target-ith
#
# target-ith: target-ith.o
# 		@$(CC) $(CFLAGS_C) $< $(LIBS) -o $@.out
# ------------------------------------------------------------------------

LIBS =

CC = clang
CFLAGS_C = -std=c11 -g -Wall

CCPP = clang++
CFLAGS_CPP = -std=c++11 -g -Wall

# If the first argument is "run"...
ifeq (run,$(firstword $(MAKECMDGOALS)))
  # use the rest as arguments for "run"
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  # ...and turn them into do-nothing targets
  $(eval $(RUN_ARGS):;@:)
endif

.PHONY: default all clean run $(TARGETS)

default: $(TARGET)
all: $(TARGETS)

OBJECTS_C = $(patsubst %.c, %.o, $(wildcard *.c))
OBJECTS_CPP = $(patsubst %.cpp, %.o, $(wildcard *.cpp))
HEADERS = $(wildcard *.h)

%.o: %.c $(HEADERS)
	@$(CC) $(CFLAGS_C) -c $< -o $@

%.o: %.cpp $(HEADERS)
	@$(CCPP) $(CFLAGS_CPP) -c $< -o $@

.PRECIOUS: $(TARGETS) $(OBJECTS_CPP) $(OBJECTS_C)

clean:
	@rm -f *.o *.out

run: $(TARGET)
	$(TARGET).out $(RUN_ARGS)

