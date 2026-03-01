// =============================================================================
// tb_ffn_3stages.sv
// SystemVerilog testbench for ffn_3stages_top.
//
// Uses the same matrix constants as the original VHDL testbench.
// Q8.8 helper functions convert real values to/from the fixed-point format.
// The testbench:
//   1. Resets the DUT
//   2. Loads mat_a, mat_b, mat_c with Q8.8-converted values
//   3. Waits for results and prints them via $display
//
// This is an intentionally straightforward directed testbench equivalent to
// the original VHDL testbench. For production-quality verification, replace
// with a cocotb or OSVVM constrained-random environment.
//
// Replaces testbench_FFN_3stages.vhd
// =============================================================================

`timescale 1ns/1ps

module tb_ffn_3stages;
    import ffn_pkg::*;

    // =========================================================================
    // DUT port connections
    // =========================================================================
    logic         clk;
    logic         rst_n;
    mat_2d_8_8_t  mat_a, mat_b, mat_c;
    logic [15:0]  b_col_1, b_col_2;
    logic [15:0]  final_out [0:7];

    ffn_3stages_top dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .mat_a    (mat_a),
        .mat_b    (mat_b),
        .mat_c    (mat_c),
        .b_col_1  (b_col_1),
        .b_col_2  (b_col_2),
        .final_out(final_out)
    );

    // =========================================================================
    // Clock generation (10 ns period)
    // =========================================================================
    localparam CLK_PERIOD = 10;
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================================
    // Q8.8 helper functions
    // =========================================================================

    // Real -> Q8.8 (signed 16-bit)
    function automatic logic signed [15:0] to_q88(input real val);
        int scaled;
        scaled = int'(val * 256.0);
        if (scaled >  32767) scaled =  32767;
        if (scaled < -32768) scaled = -32768;
        return 16'(signed'(scaled));
    endfunction

    // Q8.8 (signed 16-bit) -> real string for display
    function automatic real from_q88(input logic [15:0] slv);
        return real'(signed'(slv)) / 256.0;
    endfunction

    // Q8.8 multiply emulation (mirrors the hardware truncation)
    function automatic real q88_mult(input real a, input real b);
        int a_int, b_int, prod;
        a_int = int'(a * 256.0);
        b_int = int'(b * 256.0);
        prod  = (a_int * b_int) / 256;
        return real'(prod) / 256.0;
    endfunction

    // =========================================================================
    // Test matrix constants (same as VHDL testbench)
    // =========================================================================
    real MAT_A_REAL [0:7][0:7] = '{
        '{0.1,  0.3,  0.5, 0.7,  0.3,  0.2,  0.1, 0.0},
        '{0.02, 0.45, 0.6, 0.85, 0.02, 0.08, 0.3, 0.12},
        '{0.0,  0.0,  0.0, 0.0,  0.0,  0.0,  0.0, 0.0},
        '{0.0,  0.0,  0.0, 0.0,  0.0,  0.0,  0.0, 0.0},
        '{0.0,  0.0,  0.0, 0.0,  0.0,  0.0,  0.0, 0.0},
        '{0.0,  0.0,  0.0, 0.0,  0.0,  0.0,  0.0, 0.0},
        '{0.0,  0.0,  0.0, 0.0,  0.0,  0.0,  0.0, 0.0},
        '{0.0,  0.0,  0.0, 0.0,  0.0,  0.0,  0.0, 0.0}
    };

    real MAT_B_REAL [0:7][0:7] = '{
        '{0.1,  0.8,  0.3,  0.2,  0.0, 0.0, 0.0, 0.0},
        '{0.2,  0.36, 0.2,  0.52, 0.0, 0.0, 0.0, 0.0},
        '{0.03, 0.2,  0.1,  0.7,  0.0, 0.0, 0.0, 0.0},
        '{0.04, 0.14, 0.0,  0.9,  0.0, 0.0, 0.0, 0.0},
        '{0.05, 0.1,  0.29, 0.1,  0.0, 0.0, 0.0, 0.0},
        '{0.62, 0.12, 0.4,  0.75, 0.0, 0.0, 0.0, 0.0},
        '{0.07, 0.9,  0.34, 0.1,  0.0, 0.0, 0.0, 0.0},
        '{0.88, 0.4,  0.1,  0.4,  0.0, 0.0, 0.0, 0.0}
    };

    real MAT_C_REAL [0:7][0:7] = '{
        '{0.1,  5.0,  9.0,  1.0, 4.0, 2.0, 3.0, 9.0},
        '{2.2,  6.0,  10.4, 3.0, 6.0, 3.7, 1.0, 7.6},
        '{3.0,  7.2,  11.0, 2.3, 3.0, 1.0, 2.8, 6.0},
        '{4.0,  8.0,  12.0, 5.0, 2.0, 0.0, 9.0, 5.0},
        '{0.0,  0.0,  0.0,  0.0, 0.0, 0.0, 0.0, 0.0},
        '{0.0,  0.0,  0.0,  0.0, 0.0, 0.0, 0.0, 0.0},
        '{0.0,  0.0,  0.0,  0.0, 0.0, 0.0, 0.0, 0.0},
        '{0.0,  0.0,  0.0,  0.0, 0.0, 0.0, 0.0, 0.0}
    };

    // =========================================================================
    // Stimulus
    // =========================================================================
    localparam GELU_LATENCY = 4;

    initial begin
        // Initialise signals
        rst_n   = 1'b0;
        b_col_1 = '0;
        b_col_2 = '0;
        mat_a   = '{default: '{default: '0}};
        mat_b   = '{default: '{default: '0}};
        mat_c   = '{default: '{default: '0}};

        // --- Load matrices before releasing reset (matches VHDL TB order) ---
        $display("Loading matrices...");
        for (int k = 0; k < 8; k++) begin
            @(posedge clk);
            for (int r = 0; r < 8; r++)
                mat_a[r][k] = to_q88(MAT_A_REAL[r][k]);
            for (int c = 0; c < 8; c++) begin
                mat_b[k][c] = to_q88(MAT_B_REAL[k][c]);
                mat_c[k][c] = to_q88(MAT_C_REAL[k][c]);
            end
        end

        // --- Reset ---
        @(posedge clk);
        rst_n = 1'b0;
        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        repeat(2) @(posedge clk);

        // --- Wait for FSM to process and produce outputs ---
        // IDLE(1) + LOAD(8) + READ_AB_INIT(1) + READ_AB(8) + GELU_LAT(4)
        // + READ_FINAL_INIT(1) + READ_FINAL(8) = ~31 cycles
        $display("Waiting for results...");
        repeat(40) @(posedge clk);

        // --- Print results ---
        $display("");
        $display("========== FINAL OUTPUT VECTOR ==========");
        for (int r = 0; r < 8; r++) begin
            $display("  final_out[%0d] = %f  (raw hex: %04h)",
                     r, from_q88(final_out[r]), final_out[r]);
        end

        // --- Golden reference: stage 1 only (MAC A x B), rows 0 & 1 ---
        $display("");
        $display("========== STAGE 1 GOLDEN (software A x B) ==========");
        for (int r = 0; r < 2; r++) begin
            for (int c = 0; c < 8; c++) begin
                real sum;
                sum = 0.0;
                for (int k = 0; k < 8; k++)
                    sum = sum + q88_mult(MAT_A_REAL[r][k], MAT_B_REAL[k][c]);
                $display("  A_row%0d x B_col%0d = %f", r, c, sum);
            end
        end

        $display("");
        $display("Test finished.");
        $finish;
    end

    // =========================================================================
    // Optional: assertion — FSM must not produce X on outputs
    // =========================================================================
    // synthesis translate_off
    always @(posedge clk) begin
        if (rst_n) begin
            for (int i = 0; i < 8; i++) begin
                assert (!$isunknown(final_out[i]))
                    else $warning("final_out[%0d] contains X/Z at time %0t", i, $time);
            end
        end
    end
    // synthesis translate_on

endmodule : tb_ffn_3stages
