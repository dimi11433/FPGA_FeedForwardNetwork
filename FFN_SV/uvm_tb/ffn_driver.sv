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
        vif.cb.start     <= 0;
        vif.cb.sample_en <= 0;
        @(vif.cb);

        forever begin
            seq_item_port.get_next_item(req);
            ap.write(req);
            drive_transaction(req);
            seq_item_port.item_done();
        end
    endtask

    // Pipeline latency: mac1(1) + gelu_reg(1) + mac2(1) + y_reg(1) + done_d1(1) + done(1) = ~6
    // Use generous settle time to guarantee done has fired and y is stable.
    localparam int SETTLE_CYCLES = 10;
    localparam int IDLE_GAP      = 2;

    virtual task drive_transaction(ffn_transaction tr);
        // Drive inputs
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
        vif.cb.rst_n <= 1;

        // Assert start — hold for a few cycles to feed both pipeline layers
        vif.cb.start <= 1;
        repeat (SETTLE_CYCLES - 1) @(vif.cb);

        // Pulse sample_en so the monitor captures y and y_ref
        vif.cb.sample_en <= 1;
        @(vif.cb);
        vif.cb.sample_en <= 0;

        // Deassert start — this is the key toggle coverage fix
        vif.cb.start <= 0;

        // Idle gap between transactions ensures start toggles 0→1→0
        repeat (IDLE_GAP) @(vif.cb);
    endtask
endclass

`endif
