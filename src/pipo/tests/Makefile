# Makefile
PWD=$(shell pwd)

HDLDIR = $(PWD)/../sv
export PYTHONPATH := $(PWD)/../model:$(PYTHONPATH)

#Point to the correct SDK cpp files
CXXFLAGS += -isysroot $(shell xcrun --sdk macosx --show-sdk-path)

# defaults
SIM ?= verilator #icarus
TOPLEVEL_LANG ?= verilog

EXTRA_ARGS += --coverage --trace --trace-fst --trace-structs

VERILOG_SOURCES += $(HDLDIR)/pipo_reg.sv

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = pipo_reg

# MODULE is the basename of the Python test file
MODULE = test_pipo_reg

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim