# Makefile
PWD=$(shell pwd)

HDLDIR = $(PWD)/../rtl
//export PYTHONPATH := $(PWD)/../model:$(PYTHONPATH)

#Point to the correct SDK cpp files
CXXFLAGS += -isysroot $(shell xcrun --sdk macosx --show-sdk-path)

# defaults
SIM ?= verilator #icarus
TOPLEVEL_LANG ?= verilog

EXTRA_ARGS += --coverage --trace --trace-fst --trace-structs

VERILOG_SOURCES += $(HDLDIR)/pwm.sv
VERILOG_SOURCES += $(HDLDIR)/arty_s7_hello_world_toplevel.sv

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = arty_s7_hello_world_toplevel

# MODULE is the basename of the Python test file
MODULE = test_hello_world

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim