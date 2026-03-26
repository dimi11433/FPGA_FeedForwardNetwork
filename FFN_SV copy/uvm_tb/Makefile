# UVM testbench for top-level FFN design
# Requires: UVM_HOME set (e.g. export UVM_HOME=/path/to/uvm-1.2)
# Simulator: ModelSim/Questa, VCS, or Xcelium

UVM_HOME ?= $(QUESTA_HOME)/verilog_src/uvm-1.2
TOP_DIR   = $(shell pwd)
FFN_ROOT  = $(TOP_DIR)/..
RTL_DIR   = $(FFN_ROOT)/My_Impl

VLOG_OPTS = -sv +incdir+$(RTL_DIR)/MatMul/add-mul-modules
VLOG_OPTS += +incdir+$(RTL_DIR)/MatMul/main_mac_modules
VLOG_OPTS += +incdir+$(RTL_DIR)/Stage1
VLOG_OPTS += +incdir+$(RTL_DIR)/top_level

# Source files (order matters for includes)
RTL_SRCS = \
  $(RTL_DIR)/MatMul/add-mul-modules/fp32_mul.sv \
  $(RTL_DIR)/MatMul/add-mul-modules/fp32_add.sv \
  $(RTL_DIR)/MatMul/main_mac_modules/mac_8cyc.sv \
  $(RTL_DIR)/MatMul/main_mac_modules/8mac.sv \
  $(RTL_DIR)/Stage1/bf16-LUT.sv \
  $(RTL_DIR)/Stage1/gelu-LUT.sv \
  $(RTL_DIR)/Stage1/st1.sv \
  $(RTL_DIR)/top_level/top.sv

UVM_SRCS = \
  $(TOP_DIR)/ffn_if.sv \
  $(TOP_DIR)/ffn_transaction.sv \
  $(TOP_DIR)/ffn_sequence.sv \
  $(TOP_DIR)/ffn_driver.sv \
  $(TOP_DIR)/ffn_monitor.sv \
  $(TOP_DIR)/ffn_agent.sv \
  $(TOP_DIR)/ffn_ref_model.sv \
  $(TOP_DIR)/ffn_scoreboard.sv \
  $(TOP_DIR)/ffn_env.sv \
  $(TOP_DIR)/ffn_test.sv \
  $(TOP_DIR)/ffn_pkg.sv \
  $(TOP_DIR)/ffn_uvm_tb.sv

# Questa/ModelSim
questa: $(RTL_SRCS) $(UVM_SRCS)
	vlib work
	vlog $(VLOG_OPTS) +incdir+$(UVM_HOME)/src $(UVM_HOME)/src/uvm_pkg.sv
	vlog $(VLOG_OPTS) $(RTL_SRCS)
	vlog $(VLOG_OPTS) +incdir+$(TOP_DIR) $(UVM_SRCS)
	vsim -c -do "run -all; quit" ffn_uvm_tb

questa_gui:
	$(MAKE) questa
	vsim -gui ffn_uvm_tb &

.PHONY: questa questa_gui clean

clean:
	rm -rf work transcript vsim.wlf *.log
