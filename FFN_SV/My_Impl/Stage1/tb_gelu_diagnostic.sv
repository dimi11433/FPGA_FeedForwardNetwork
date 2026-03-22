`timescale 1ns/1ps
// GELU diagnostic: drive 1.0 into gelu_pwl and dump all intermediates.
// Expected: GELU(1.0) ≈ 0.84 (0x3F57 or 0x3F58 in bf16)
// Run with: vlog -sv bf16-LUT.sv gelu-LUT.sv st1.sv fp32_mul.sv fp32_add.sv tb_gelu_diagnostic.sv
// (adjust paths to fp32_mul, fp32_add as needed)

module tb_gelu_diagnostic;

    localparam int N = 2;

    logic       clk;
    logic       rst_n;
    logic [15:0] data_in  [0:N-1];
    logic [15:0] data_out [0:N-1];

    gelu_pwl #(.N(N)) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .data_in (data_in),
        .data_out(data_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        data_in[0] = 16'h0000;
        data_in[1] = 16'h0000;

        repeat (3) @(posedge clk);
        rst_n = 1;

        // Drive 1.0 into lane 0 (GELU-relevant case)
        data_in[0] = 16'h3F80;   // 1.0 in bf16
        data_in[1] = 16'h3F80;   // 1.0 in lane 1 too for symmetry

        repeat (3) @(posedge clk);  // let pipeline capture result

        $display("=== GELU diagnostic: data_in = 1.0 (0x3F80) ===\n");
        $display("Lane 0:");
        $display("  bf16_index  = %0d", dut.bf16_index[0]);
        $display("  slope       = 0x%04h", dut.slope[0]);
        $display("  intercept   = 0x%04h", dut.intercept[0]);
        $display("  slope_long  = 0x%08h", dut.slope_long[0]);
        $display("  data_long   = 0x%08h", dut.data_long[0]);
        $display("  reg_out1    = 0x%08h  (mul: slope * data_in)", dut.reg_out1[0]);
        $display("  intercept_long = 0x%08h", dut.intercept_long[0]);
        $display("  reg_out2    = 0x%08h  (add: mul + intercept)", dut.reg_out2[0]);
        $display("  data_out    = 0x%04h  (fp32->bf16)", dut.data_out[0]);
        $display("");
        $display("Expected: reg_out2 ≈ 0x3F570000 (~0.84), data_out ≈ 0x3F57 or 0x3F58");
        $display("If reg_out2 is ~8x too large (e.g. 0x41010000), bug is in fp32_add or earlier.");
        $finish;
    end

endmodule
