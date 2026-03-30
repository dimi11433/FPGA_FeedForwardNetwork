`ifndef FFN_DRIVER_SV
`define FFN_DRIVER_SV

`include "uvm_macros.svh"
`include "uvm_pkg.sv"
import uvm_pkg::*;
`include "ffn_transaction.sv"
`include "ffn_if.sv"

class ffn_driver extends uvm_driver #(ffn_transaction);
    parameter int N = 2;

    virtual ffn_if vif;
    uvm_analysis_port #(ffn_transaction) ap;

    `uvm_component_utils(ffn_driver)

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual ffn_if)::get(this, "", "vif", vif))
            `uvm_fatal("FFN_DRV", "Virtual interface not found")
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            // Enqueue the expected result before we wait/sampling output
            // so the scoreboard FIFO order matches.
            ap.write(req);
            drive_transaction(req);
            seq_item_port.item_done();
        end
    endtask

    localparam int LATENCY = 20;  // Hold inputs this long, then sample once

    virtual task drive_transaction(ffn_transaction tr);
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) begin
                vif.cb.w1[i][j] <= tr.w1[i][j];
                vif.cb.w2[i][j] <= tr.w2[i][j];
            end
        for (int i = 0; i < N; i++) begin
            vif.cb.b1[i] <= tr.b1[i];
            vif.cb.b2[i] <= tr.b2[i];
            vif.cb.x[i]  <= tr.x[i];
        end
        vif.cb.rst_n     <= 1;  // ensure deasserted
        vif.cb.sample_en <= 0;

        // Keep inputs stable; DUT pipeline will settle to a steady output.
        repeat (LATENCY-1) @(vif.cb);

        // One-cycle sampling pulse for the monitor.
        vif.cb.sample_en <= 1;
        @(vif.cb);
        vif.cb.sample_en <= 0;
    endtask
endclass

`endif
