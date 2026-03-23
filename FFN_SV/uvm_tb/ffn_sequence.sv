`ifndef FFN_SEQUENCE_SV
`define FFN_SEQUENCE_SV

`include "uvm_macros.svh"
`include "uvm_pkg.sv"
import uvm_pkg::*;
`include "ffn_transaction.sv"

class ffn_sequence extends uvm_sequence #(ffn_transaction);
    `uvm_object_utils(ffn_sequence)

    rand int num_transactions = 5;

    constraint reasonable_num { num_transactions inside {[1:20]}; }

    function new(string name = "ffn_sequence");
        super.new(name);
    endfunction

    virtual task body();
        for (int i = 0; i < num_transactions; i++) begin
            `uvm_do(req)
        end
    endtask
endclass

`endif
