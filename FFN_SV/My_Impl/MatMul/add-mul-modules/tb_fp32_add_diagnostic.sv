`timescale 1ns/1ps
// fp32_add diagnostic: GELU-relevant case
// slope*1.0 + intercept ≈ 0.84 for input 1.0
// For bf16 index 29: slope=0x3F8D (~1.1), intercept=0xBE87 (~-0.26)
// So: 1.1 + (-0.26) ≈ 0.84
// Run with: vlog -sv fp32_add.sv tb_fp32_add_diagnostic.sv

module tb_fp32_add_diagnostic;
    logic [31:0] a, b, result;
    fp32_add dut (.a(a), .b(b), .result(result));

    // bf16 → fp32
    function logic [31:0] bf16_to_fp32(logic [15:0] bf16);
        return {bf16, 16'b0};
    endfunction

    initial begin
        $display("=== fp32_add diagnostic: GELU-style add ===\n");

        // Test 1: 1.1 + (-0.26) ≈ 0.84  (slope*1.0 + intercept for input 1.0)
        a = bf16_to_fp32(16'h3F8D);   // ~1.1 (slope from gelu LUT index 29)
        b = bf16_to_fp32(16'hBE87);   // ~-0.26 (intercept)
        #1;
        $display("1.1 + (-0.26): result=0x%08h upper16=0x%04h", result, result[31:16]);
        $display("  Expected: ~0x3E57xxxx (0.84, exp=126), upper16 ~0x3E57");
        $display("  Note: 0x3F56 (exp=127) = ~1.67, so result would be 2x too large");
        $display("  Debug: m_raw=0x%07h mpos=%0d lshift=%0d round_bit=%0d m_ext[23]=%0d e_out=%0d e_final=%0d",
                 dut.m_raw, dut.mpos, dut.lshift, dut.round_bit, dut.m_ext[23], dut.e_out, dut.e_final);

        // Test 2: 0.84 + 0 = 0.84
        a = bf16_to_fp32(16'h3F57);
        b = bf16_to_fp32(16'h0000);
        #1;
        $display("0.84 + 0:     result=0x%08h upper16=0x%04h", result, result[31:16]);

        // Test 3: 1.0 + (-1.0) = 0 (cancellation)
        a = bf16_to_fp32(16'h3F80);
        b = bf16_to_fp32(16'hBF80);
        #1;
        $display("1.0 + (-1.0): result=0x%08h (should be 0)", result);

        $display("\nIf 1.1+(-0.26) gives ~8x (e.g. 0x41010000), fp32_add has a bug.");
        $finish;
    end

endmodule
