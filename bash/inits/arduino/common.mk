# vim: ts=4 list

# Followings have to be set in env:
# export ARDUINO_DIR=$HOME/Applications/Arduino.app/Contents/Java
# export ARDMK_DIR=$MY_PROJ_PATH/oth/Arduino-Makefile

# Common:
CTAGS_PATH    = $(ARDUINO_DIR)/tools-builder/ctags/5.8-arduino11/ctags
MONITOR_PORT ?= /dev/ttyACM0

ARDUINO_SKETCHBOOK ?= $(ARDUINO_DIR)

include $(ARDMK_DIR)/Arduino.mk

.PHONY: tags-all monitor

tags-all:
	-@$(CTAGS_PATH) -f tags.cpp $(shell find . -name "*.cpp" -o -name "*.h") $(shell find $(ARDUINO_DIR)/libraries -name "*.cpp" -o -name "*.h")
	-@$(CTAGS_PATH) -f tags.ino --langmap=c++:.ino $(shell find . -name "*.ino")
	-@cat tags.cpp tags.ino | sort > tags
	-@rm -f tags.*

monitor:
	$(SCRIPT_PATH)/console/console.sh $(MONITOR_PORT)

