`timescale 1ns/1ps
// Diagnostic testbench: 1.0 * x must equal x.
// Run this to isolate whether fp32_mul or conversion is causing the 8x error.

module tb_fp32_mul_diagnostic;
    logic [31:0] a, b, result;
    fp32_mul dut (.a(a), .b(b), .result(result));

    // bf16 → fp32
    function logic [31:0] bf16_to_fp32(logic [15:0] bf16);
        return {bf16, 16'b0};
    endfunction

    initial begin
        $display("=== fp32_mul diagnostic: 1.0 * x == x ===\n");

        // Test 1: 1.0 * 1.0 = 1.0
        a = bf16_to_fp32(16'h3F80);  // 1.0
        b = bf16_to_fp32(16'h3F80);  // 1.0
        #1;
        $display("1.0 * 1.0: result=0x%08h (exp=%0d) expected 0x3F800000 (1.0)", 
                 result, result[30:23]);

        // Test 2: 1.0 * 0.5 = 0.5  (catches exp+1 error)
        a = bf16_to_fp32(16'h3F80);  // 1.0
        b = bf16_to_fp32(16'h3F00);  // 0.5
        #1;
        $display("1.0 * 0.5:  result=0x%08h (exp=%0d) expected 0x3F000000 (0.5)", 
                 result, result[30:23]);

        // Test 3: 1.0 * 0.84 ≈ 0.84  (GELU-relevant)
        a = bf16_to_fp32(16'h3F80);  // 1.0
        b = bf16_to_fp32(16'h3F57);  // ~0.84 in bf16
        #1;
        $display("1.0 * 0.84: result=0x%08h (exp=%0d) expected exp~126, ~0.84", 
                 result, result[30:23]);

        // Test 4: slope-like value * 1.0
        a = bf16_to_fp32(16'h3F80);  // 1.0 (as data_in)
        b = bf16_to_fp32(16'h3E5C);  // slope from gelu LUT index 15
        #1;
        $display("1.0 * slope: result=0x%08h upper16=0x%04h", result, result[31:16]);

        $display("\nIf exp is 3 too high (e.g. 130 vs 127), mantissa slice is wrong.");
        $finish;
    end
endmodule
