`ifndef FFN_ENV_SV
`define FFN_ENV_SV

`include "uvm_macros.svh"
`include "uvm_pkg.sv"
import uvm_pkg::*;
`include "ffn_agent.sv"
`include "ffn_ref_model.sv"
`include "ffn_scoreboard.sv"

class ffn_env extends uvm_env;
    parameter int N = 2;

    ffn_agent      agt;
    ffn_ref_model  ref_model;
    ffn_scoreboard scb;

    `uvm_component_utils(ffn_env)

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt       = ffn_agent::type_id::create("agt", this);
        ref_model = ffn_ref_model::type_id::create("ref_model", this);
        scb       = ffn_scoreboard::type_id::create("scb", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.ap.connect(scb.exp_export);
        agt.mon.ap.connect(scb.act_export);
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        if (scb.num_compared > 0 && scb.num_matches == scb.num_compared)
            `uvm_info("ENV", "*** UVM TEST PASSED ***", UVM_NONE)
        else
            `uvm_error("ENV", "*** UVM TEST FAILED ***")
    endfunction
endclass

`endif
