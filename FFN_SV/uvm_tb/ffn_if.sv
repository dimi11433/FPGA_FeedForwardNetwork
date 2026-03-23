`ifndef FFN_IF_SV
`define FFN_IF_SV

interface ffn_if #(parameter int N = 2) (input logic clk);
    logic rst_n;
    logic [15:0] w1 [0:N-1][0:N-1];
    logic [15:0] w2 [0:N-1][0:N-1];
    logic [15:0] b1 [0:N-1][0:N-1];
    logic [15:0] b2 [0:N-1][0:N-1];
    logic [15:0] x  [0:N-1][0:N-1];
    logic [15:0] y  [0:N-1][0:N-1];
    logic [15:0] y_ref [0:N-1][0:N-1];
    logic sample_en;

    clocking cb @(posedge clk);
        output rst_n, w1, w2, b1, b2, x, sample_en;
        input  y, y_ref;
    endclocking

    modport tb (clocking cb);
    modport dut (input clk, rst_n, w1, w2, b1, b2, x, output y);
endinterface

`endif
