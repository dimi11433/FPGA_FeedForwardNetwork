`ifndef FFN_AGENT_SV
`define FFN_AGENT_SV

`include "uvm_macros.svh"
`include "uvm_pkg.sv"
import uvm_pkg::*;
`include "ffn_transaction.sv"
`include "ffn_driver.sv"
`include "ffn_monitor.sv"

class ffn_agent extends uvm_agent;
    parameter int N = 2;

    ffn_driver  drv;
    ffn_monitor mon;
    uvm_sequencer #(ffn_transaction) sqr;

    `uvm_component_utils(ffn_agent)

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = ffn_monitor::type_id::create("mon", this);
        if (is_active == UVM_ACTIVE) begin
            drv = ffn_driver::type_id::create("drv", this);
            sqr = uvm_sequencer#(ffn_transaction)::type_id::create("sqr", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (is_active == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

`endif
