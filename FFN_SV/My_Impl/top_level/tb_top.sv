`timescale 1ns/1ps

// Testbench for top.sv - FFN with MAC -> GELU -> MAC pipeline
// Uses N=2 (2x2) and small, hand-verifiable inputs

module tb_top;

    localparam int N = 2;

    logic       clk;
    logic       rst_n;
    logic [15:0] w1 [0:N-1][0:N-1];
    logic [15:0] w2 [0:N-1][0:N-1];
    logic [15:0] b1 [0:N-1][0:N-1];
    logic [15:0] b2 [0:N-1][0:N-1];
    logic [15:0] x  [0:N-1][0:N-1];
    logic [15:0] y  [0:N-1][0:N-1];

    top #(.N(N)) dut (
        .clk (clk),
        .rst_n(rst_n),
        .w1  (w1),
        .w2  (w2),
        .b1  (b1),
        .b2  (b2),
        .x   (x),
        .y   (y)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        int i, j, c;
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);

        rst_n = 0;
        for (i = 0; i < N; i++) begin
            for (j = 0; j < N; j++) begin
                w1[i][j] = 16'h0000;
                w2[i][j] = 16'h0000;
                b1[i][j] = 16'h0000;
                b2[i][j] = 16'h0000;
                x[i][j]  = 16'h0000;
            end
        end

        repeat (3) @(posedge clk);
        rst_n = 1;

        // Small bf16-style values (easy to check by hand):
        // 16'h3F80 ~= 1.0,  16'h4000 ~= 2.0,  16'h0000 = 0
        w1[0][0] = 16'h3F80; w1[0][1] = 16'h0000;
        w1[1][0] = 16'h0000; w1[1][1] = 16'h3F80;

        w2[0][0] = 16'h3F80; w2[0][1] = 16'h0000;
        w2[1][0] = 16'h0000; w2[1][1] = 16'h3F80;

        b1[0][0] = 16'h0000; b1[0][1] = 16'h0000;
        b1[1][0] = 16'h0000; b1[1][1] = 16'h0000;

        b2[0][0] = 16'h0000; b2[0][1] = 16'h0000;
        b2[1][0] = 16'h0000; b2[1][1] = 16'h0000;

        x[0][0]  = 16'h3F80; x[0][1]  = 16'h0000;   // input [1, 0]
        x[1][0]  = 16'h0000; x[1][1]  = 16'h3F80;   //       [0, 1]

        $display("--- Inputs (bf16) ---");
        $display("w1: [%04h %04h]  w2: [%04h %04h]", w1[0][0], w1[0][1], w2[0][0], w2[0][1]);
        $display("    [%04h %04h]      [%04h %04h]", w1[1][0], w1[1][1], w2[1][0], w2[1][1]);
        $display("x:  [%04h %04h]  b1,b2 = 0", x[0][0], x[0][1]);
        $display("    [%04h %04h]", x[1][0], x[1][1]);

        // 2x2: MAC1 (4 cyc) + GELU (1 cyc) + MAC2 (4 cyc) + output reg (1 cyc) ≈ 10 cyc
        repeat (15) @(posedge clk);

        $display("--- GELU output (post MAC1) ---");
        $display("gelu_out: [%04h %04h]", dut.gelu_out[0][0], dut.gelu_out[0][1]);
        $display("          [%04h %04h]", dut.gelu_out[1][0], dut.gelu_out[1][1]);
        $display("--- Final outputs (post MAC2) ---");
        $display("y: [%04h %04h]", y[0][0], y[0][1]);
        $display("   [%04h %04h]", y[1][0], y[1][1]);
        $display("tb_top done.");
        $finish;
    end

endmodule
