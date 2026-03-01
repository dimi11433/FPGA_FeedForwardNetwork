// =============================================================================
// gelu_pwl.sv
// 4-stage pipelined GeLU activation using piecewise-linear (PWL) approximation.
//
// Input range: Q8.8 signed [-4.0, +4.0]
//   - Saturates to x     if x >= +4.0
//   - Saturates to 0     if x <  -4.0
//   - Otherwise: gelu(x) ~= slope * x + intercept  (from LUT)
//
// LUT index = input[10:6]  (5-bit unsigned, 0-31)
//
// Pipeline stages:
//   S1: range check, index compute
//   S2: fetch slope and intercept from LUT
//   S3: multiply slope * x  (32-bit result)
//   S4: add intercept, re-align to Q8.8, apply saturation
//
// Replaces gelu_pwl.vhd
// =============================================================================

module gelu_pwl
    import ffn_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [15:0] data_in,
    output logic [15:0] data_out
);

    // Q8.8 saturation boundaries
    localparam logic signed [15:0] MAX_RANGE = 16'h0400;  // +4.0
    localparam logic signed [15:0] MIN_RANGE = 16'hFC00;  // -4.0

    // ---------- Stage 1 pipeline registers ----------
    logic [4:0]           s1_index;
    logic signed [15:0]   s1_dx;
    logic                 s1_sat_p, s1_sat_n;

    // ---------- Stage 2 pipeline registers ----------
    logic signed [15:0]   s2_slope, s2_intercept, s2_dx;
    logic                 s2_sat_p, s2_sat_n;

    // ---------- Stage 3 pipeline registers ----------
    logic signed [31:0]   s3_mult_res;
    logic signed [15:0]   s3_intercept, s3_dx;
    logic                 s3_sat_p, s3_sat_n;

    logic signed [15:0]   data_out_s;
    assign data_out = data_out_s;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_index   <= '0;  s1_dx      <= '0;
            s1_sat_p   <= '0;  s1_sat_n   <= '0;
            s2_slope   <= '0;  s2_intercept <= '0;
            s2_dx      <= '0;  s2_sat_p   <= '0;  s2_sat_n <= '0;
            s3_mult_res <= '0; s3_intercept <= '0;
            s3_dx      <= '0;  s3_sat_p   <= '0;  s3_sat_n <= '0;
            data_out_s <= '0;
        end else begin

            // ==============================================================
            // STAGE 1: Range check and LUT index extraction
            // ==============================================================
            s1_dx    <= signed'(data_in);
            s1_sat_p <= (signed'(data_in) >= MAX_RANGE);
            s1_sat_n <= (signed'(data_in) <  MIN_RANGE);
            s1_index <= data_in[10:6];   // 5-bit unsigned index into LUT

            // ==============================================================
            // STAGE 2: Fetch slope and intercept from LUT
            // ==============================================================
            s2_slope     <= M_LUT[s1_index];
            s2_intercept <= C_LUT[s1_index];
            s2_dx        <= s1_dx;
            s2_sat_p     <= s1_sat_p;
            s2_sat_n     <= s1_sat_n;

            // ==============================================================
            // STAGE 3: Multiply slope * dx  (Q8.8 * Q8.8 -> Q16.16)
            // ==============================================================
            s3_mult_res  <= s2_slope * s2_dx;
            s3_intercept <= s2_intercept;
            s3_dx        <= s2_dx;
            s3_sat_p     <= s2_sat_p;
            s3_sat_n     <= s2_sat_n;

            // ==============================================================
            // STAGE 4: Add intercept, re-align to Q8.8, apply saturation
            //   mult_res is Q16.16 (32-bit)
            //   intercept is Q8.8  -> shift left by 8 to make Q16.16
            //   sum is Q16.16; extract bits [27:12] to get Q8.8 output
            // ==============================================================
            begin
                logic signed [31:0] intercept_hi;
                logic signed [31:0] sum_q16_16;

                intercept_hi = 32'(s3_intercept) <<< 8;
                sum_q16_16   = s3_mult_res + intercept_hi;

                if (s3_sat_p)
                    data_out_s <= s3_dx;           // pass through (x ~= gelu(x) for large x)
                else if (s3_sat_n)
                    data_out_s <= '0;              // gelu(x) ~= 0 for very negative x
                else
                    data_out_s <= sum_q16_16[27:12]; // Q16.16 -> Q8.8
            end
        end
    end

endmodule : gelu_pwl
