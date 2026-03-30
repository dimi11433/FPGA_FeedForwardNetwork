`ifndef FFN_MONITOR_SV
`define FFN_MONITOR_SV

`include "uvm_macros.svh"
`include "uvm_pkg.sv"
import uvm_pkg::*;
`include "ffn_transaction.sv"
`include "ffn_if.sv"

class ffn_monitor extends uvm_monitor;
    parameter int N = 2;

    virtual ffn_if vif;
    uvm_analysis_port #(ffn_transaction) ap;

    `uvm_component_utils(ffn_monitor)

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual ffn_if)::get(this, "", "vif", vif))
            `uvm_fatal("FFN_MON", "Virtual interface not found")
    endfunction

    virtual task run_phase(uvm_phase phase);
        logic [15:0] y_dut_sample [0:N-1];
        logic [15:0] y_ref_sample [0:N-1];
        forever begin
            @(vif.cb);
            if (vif.rst_n && vif.sample_en) begin
                for (int i = 0; i < N; i++)
                    begin
                        y_dut_sample[i] = vif.cb.y[i];
                        y_ref_sample[i] = vif.cb.y_ref[i];
                    end
                push_transaction(y_ref_sample, y_dut_sample);
            end
        end
    endtask

    virtual function void push_transaction(
        logic [15:0] y_ref_sample [0:N-1],
        logic [15:0] y_dut_sample [0:N-1]
    );
        ffn_transaction tr;
        tr = ffn_transaction::type_id::create("tr");
        for (int i = 0; i < N; i++)
            begin
                tr.y_exp[i] = y_ref_sample[i];
                tr.y_act[i] = y_dut_sample[i];
            end
        ap.write(tr);
    endfunction
endclass

`endif
