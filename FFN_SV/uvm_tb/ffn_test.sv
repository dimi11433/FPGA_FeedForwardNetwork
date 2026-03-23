`ifndef FFN_TEST_SV
`define FFN_TEST_SV

`include "uvm_macros.svh"
`include "uvm_pkg.sv"
import uvm_pkg::*;
`include "ffn_env.sv"
`include "ffn_sequence.sv"

class ffn_test extends uvm_test;
    parameter int N = 2;

    ffn_env env;

    `uvm_component_utils(ffn_test)

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = ffn_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        ffn_sequence seq;
        phase.raise_objection(this);
        seq = ffn_sequence::type_id::create("seq");
        seq.num_transactions = 5;
        seq.start(env.agt.sqr);
        #1000;  // allow time for pipeline to drain
        phase.drop_objection(this);
    endtask
endclass

`endif
