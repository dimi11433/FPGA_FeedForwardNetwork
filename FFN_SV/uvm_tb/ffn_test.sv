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
        int num_txns;
        phase.raise_objection(this);

        seq = ffn_sequence::type_id::create("seq");
        num_txns = 500;
        void'($value$plusargs("NUM_TXNS=%d", num_txns));
        seq.num_transactions = num_txns;

        `uvm_info("TEST", $sformatf("Running: %0d directed corners + %0d random", 70, seq.num_transactions), UVM_LOW)
        seq.start(env.agt.sqr);

        // Drain time: let pipeline flush after last transaction
        #2000;

        // Mid-sim reset pulse to exercise reset toggle on all registers
        `uvm_info("TEST", "Applying mid-sim reset pulse for toggle coverage", UVM_LOW)
        env.agt.drv.vif.cb.rst_n <= 0;
        repeat (3) @(posedge env.agt.drv.vif.clk);
        env.agt.drv.vif.cb.rst_n <= 1;
        repeat (5) @(posedge env.agt.drv.vif.clk);

        phase.drop_objection(this);
    endtask
endclass

`endif
