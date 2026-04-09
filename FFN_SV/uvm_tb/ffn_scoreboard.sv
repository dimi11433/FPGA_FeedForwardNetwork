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
    int tolerance    = 0;

    // ---- Functional coverage ----
    logic [15:0] cov_y0, cov_y1;
    logic        cov_y0_sign, cov_y1_sign;
    logic [7:0]  cov_y0_exp,  cov_y1_exp;

    covergroup cg_output;
        // Sign toggle: both positive and negative outputs observed
        cp_y0_sign: coverpoint cov_y0_sign { bins pos = {0}; bins neg = {1}; }
        cp_y1_sign: coverpoint cov_y1_sign { bins pos = {0}; bins neg = {1}; }

        // Exponent range: zero, small, medium, large
        cp_y0_exp: coverpoint cov_y0_exp {
            bins exp_zero  = {0};
            bins exp_lo    = {[1:64]};
            bins exp_mid   = {[65:190]};
            bins exp_hi    = {[191:254]};
            bins exp_max   = {255};
        }
        cp_y1_exp: coverpoint cov_y1_exp {
            bins exp_zero  = {0};
            bins exp_lo    = {[1:64]};
            bins exp_mid   = {[65:190]};
            bins exp_hi    = {[191:254]};
            bins exp_max   = {255};
        }

        // Cross: both lanes see both signs
        cx_signs: cross cp_y0_sign, cp_y1_sign;
    endgroup

    `uvm_component_utils(ffn_scoreboard)

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
        cg_output = new();
        cg_output.start();
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

            // Coverage sampling
            cov_y0      = act_tr.y_act[0];
            cov_y1      = act_tr.y_act[1];
            cov_y0_sign = act_tr.y_act[0][15];
            cov_y1_sign = act_tr.y_act[1][15];
            cov_y0_exp  = act_tr.y_act[0][14:7];
            cov_y1_exp  = act_tr.y_act[1][14:7];
            cg_output.sample();

            num_compared++;
            if (match)
                num_matches++;
            else
                `uvm_error("SCOREBOARD", $sformatf(
                    "Mismatch #%0d: exp={0x%04h,0x%04h} act={0x%04h,0x%04h}",
                    num_compared,
                    exp_tr.y_exp[0], exp_tr.y_exp[1],
                    act_tr.y_act[0], act_tr.y_act[1]))
        end
    endtask

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCOREBOARD", $sformatf(
            "Compared %0d, matched %0d | Output coverage: %.1f%%",
            num_compared, num_matches, cg_output.get_coverage()), UVM_LOW)
    endfunction
endclass

`endif
