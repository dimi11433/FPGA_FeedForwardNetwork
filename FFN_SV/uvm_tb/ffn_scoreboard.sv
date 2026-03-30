`ifndef FFN_SCOREBOARD_SV
`define FFN_SCOREBOARD_SV

`include "uvm_macros.svh"
`include "uvm_pkg.sv"
import uvm_pkg::*;
`include "ffn_transaction.sv"

class ffn_scoreboard extends uvm_scoreboard;
    parameter int N = 2;

    uvm_analysis_export #(ffn_transaction) exp_export;
    uvm_analysis_export #(ffn_transaction) act_export;

    uvm_tlm_analysis_fifo #(ffn_transaction) exp_fifo;
    uvm_tlm_analysis_fifo #(ffn_transaction) act_fifo;

    int num_compared = 0;
    int num_matches  = 0;
    int tolerance = 0;  // RTL-based y_ref should match bit-accurately

    `uvm_component_utils(ffn_scoreboard)

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        exp_export = new("exp_export", this);
        act_export = new("act_export", this);
        exp_fifo   = new("exp_fifo", this);
        act_fifo   = new("act_fifo", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        exp_export.connect(exp_fifo.analysis_export);
        act_export.connect(act_fifo.analysis_export);
    endfunction

    virtual task run_phase(uvm_phase phase);
        ffn_transaction exp_tr, act_tr;
        bit match;
        forever begin
            exp_fifo.get(exp_tr);
            act_fifo.get(act_tr);
            match = 1;
            for (int i = 0; i < N && match; i++) begin
                int diff = exp_tr.y_exp[i] - act_tr.y_act[i];
                if (diff < 0) diff = -diff;
                if (diff > tolerance)
                    match = 0;
            end
            num_compared++;
            if (match)
                num_matches++;
            else
                `uvm_error("SCOREBOARD", $sformatf("Mismatch #%0d: exp[0]=0x%04h act[0]=0x%04h",
                    num_compared, exp_tr.y_exp[0], act_tr.y_act[0]))
        end
    endtask

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCOREBOARD", $sformatf("Compared %0d, matched %0d", num_compared, num_matches), UVM_LOW)
    endfunction
endclass

`endif
