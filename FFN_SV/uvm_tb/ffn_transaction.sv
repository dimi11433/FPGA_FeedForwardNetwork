`ifndef FFN_TRANSACTION_SV
`define FFN_TRANSACTION_SV

`include "uvm_macros.svh"
`include "uvm_pkg.sv"
import uvm_pkg::*;

class ffn_transaction extends uvm_sequence_item;
    parameter int N = 2;

    rand logic [15:0] w1 [0:N-1][0:N-1];
    rand logic [15:0] w2 [0:N-1][0:N-1];
    rand logic [15:0] b1 [0:N-1][0:N-1];
    rand logic [15:0] b2 [0:N-1][0:N-1];
    rand logic [15:0] x  [0:N-1][0:N-1];

    logic [15:0] y_exp [0:N-1][0:N-1];  // expected output (from ref model)
    logic [15:0] y_act [0:N-1][0:N-1];  // actual output (from monitor)

    constraint valid_bf16 {
        foreach (w1[i,j]) { w1[i][j][14:7] != 8'hFF; }
        foreach (w2[i,j]) { w2[i][j][14:7] != 8'hFF; }
        foreach (b1[i,j]) { b1[i][j][14:7] != 8'hFF; }
        foreach (b2[i,j]) { b2[i][j][14:7] != 8'hFF; }
        foreach (x[i,j])  { x[i][j][14:7]  != 8'hFF; }
    }

    // Keep transaction registration simple for Questa UVM 1.2.
    // (The nested-array field macros like `uvm_field_array_array_int` are not available.)
    `uvm_object_utils(ffn_transaction)

    function new(string name = "ffn_transaction");
        super.new(name);
    endfunction

    function void copy(ffn_transaction rhs);
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) begin
                w1[i][j] = rhs.w1[i][j];
                w2[i][j] = rhs.w2[i][j];
                b1[i][j] = rhs.b1[i][j];
                b2[i][j] = rhs.b2[i][j];
                x[i][j]  = rhs.x[i][j];
                y_exp[i][j] = rhs.y_exp[i][j];
                y_act[i][j] = rhs.y_act[i][j];
            end
    endfunction
endclass

`endif
