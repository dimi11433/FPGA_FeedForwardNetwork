`timescale 1ns/1ps

// Testbench for st1 (gelu_pwl) - Stage1 GELU LUT pipeline
// Input: N-wide 16-bit vector (bf16 from mat mul, e.g. mac8 data_out)
// Output: out_slope, out_intercept (PWL segment coefficients per lane)
// Upper layer: MatMul/main_mac_modules/8mac.sv produces data_out[0:N-1] (16-bit bf16)

module tb_st1;

    localparam int N = 2;  // 2x2 case as specified

    logic       clk;
    logic       rst_n;
    logic [15:0] data_in       [0:N-1];
    logic [15:0] out_intercept [0:N-1];
    logic [15:0] out_slope     [0:N-1];

    gelu_pwl #(.N(N)) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .data_in      (data_in),
        .out_intercept(out_intercept),
        .out_slope    (out_slope)
    );

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Stimulus
    initial begin
        int i, v;
        $dumpfile("tb_st1.vcd");
        $dumpvars(0, tb_st1);

        rst_n = 0;
        for (i = 0; i < N; i++) data_in[i] = '0;

        repeat (3) @(posedge clk);
        rst_n = 1;

        // Directed: bf16-like values in GELU range (from mat mul output)
        // bf16-LUT maps to indices based on value; use values that hit different regions
        data_in[0] = 16'h3F80;  // ~1.0
        data_in[1] = 16'h4000;  // ~2.0
        repeat (4) @(posedge clk);
        $display("Time %0t: data_in={0x%04h, 0x%04h} -> out_slope={0x%04h, 0x%04h} out_intercept={0x%04h, 0x%04h}",
                 $time, data_in[0], data_in[1], out_slope[0], out_slope[1], out_intercept[0], out_intercept[1]);

        // Random bf16-like inputs (mat mul typically outputs values in ~[-4, +4])
        for (v = 0; v < 20; v++) begin
            for (i = 0; i < N; i++) begin
                // Random 16-bit; can bias toward typical bf16 range if desired
                data_in[i] = $urandom;
            end
            repeat (3) @(posedge clk);
            $display("Time %0t vec %0d: data_in={0x%04h, 0x%04h} -> out_slope={0x%04h, 0x%04h} out_intercept={0x%04h, 0x%04h}",
                     $time, v, data_in[0], data_in[1], out_slope[0], out_slope[1], out_intercept[0], out_intercept[1]);
        end

        $display("tb_st1 done.");
        $finish;
    end

endmodule
