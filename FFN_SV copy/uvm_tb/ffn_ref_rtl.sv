// RTL-accurate combinational reference for top.sv
// Computes: y[i][j] = W2[i][j] * GELU(W1[i][j]*X[i][j] + B1[i][j]) + B2[i][j]
// using the same fp32_mul/fp32_add + bf16_LUT/gelu_LUT math and the same BF16 rounding rule
// as mac_8cyc and gelu_pwl.
module ffn_ref_rtl #(parameter int N = 2) (
    input  logic [15:0] w2 [0:N-1][0:N-1],
    input  logic [15:0] w1 [0:N-1][0:N-1],
    input  logic [15:0] b1 [0:N-1][0:N-1],
    input  logic [15:0] b2 [0:N-1][0:N-1],
    input  logic [15:0] x  [0:N-1][0:N-1],
    output logic [15:0] y_ref [0:N-1][0:N-1]
);

    function automatic logic [15:0] fp32_to_bf16_round(input logic [31:0] fp32);
        logic [15:0] bf;
        bf = fp32[31:16];
        // Mirror RTL rule: round-up if bit15 is set and BF16 isn't already saturated.
        if (fp32[15] && (bf != 16'hFFFF))
            fp32_to_bf16_round = bf + 16'd1;
        else
            fp32_to_bf16_round = bf;
    endfunction

    // bf16 -> fp32 (lower 16 mantissa bits are zero)
    function automatic logic [31:0] bf16_to_fp32(input logic [15:0] bf16);
        bf16_to_fp32 = {bf16, 16'h0000};
    endfunction

    logic [31:0] w1_fp32 [0:N-1][0:N-1];
    logic [31:0] x_fp32  [0:N-1][0:N-1];
    logic [31:0] b1_fp32 [0:N-1][0:N-1];
    logic [31:0] w2_fp32 [0:N-1][0:N-1];
    logic [31:0] b2_fp32 [0:N-1][0:N-1];

    logic [31:0] mac1_fp32 [0:N-1][0:N-1];
    logic [31:0] mac1_prod [0:N-1][0:N-1];
    logic [15:0] mac1_bf16 [0:N-1][0:N-1];

    logic [4:0]  gelu_idx [0:N-1][0:N-1];
    logic [15:0] gelu_slope_bf16     [0:N-1][0:N-1];
    logic [15:0] gelu_intercept_bf16 [0:N-1][0:N-1];

    logic [15:0] gelu_bf16 [0:N-1][0:N-1];

    logic [31:0] gelu_slope_fp32     [0:N-1][0:N-1];
    logic [31:0] gelu_intercept_fp32 [0:N-1][0:N-1];
    logic [31:0] gelu_in_fp32         [0:N-1][0:N-1];

    logic [31:0] gelu_out_fp32 [0:N-1][0:N-1];
    logic [31:0] gelu_mul_fp32 [0:N-1][0:N-1];
    logic [31:0] mac2_fp32     [0:N-1][0:N-1];
    logic [31:0] mac2_prod [0:N-1][0:N-1];

    logic [31:0] gelu_bf16_fp32 [0:N-1][0:N-1];

    genvar i, j;
    generate
        for (i = 0; i < N; i++) begin : gen_row1
            for (j = 0; j < N; j++) begin : gen_col1
                assign w1_fp32[i][j] = bf16_to_fp32(w1[i][j]);
                assign x_fp32[i][j]  = bf16_to_fp32(x[i][j]);
                assign b1_fp32[i][j] = bf16_to_fp32(b1[i][j]);

                assign w2_fp32[i][j] = bf16_to_fp32(w2[i][j]);
                assign b2_fp32[i][j] = bf16_to_fp32(b2[i][j]);

                fp32_mul mac1_mul2 (.a(w1_fp32[i][j]), .b(x_fp32[i][j]), .result(mac1_prod[i][j]));
                fp32_add mac1_add  (.a(mac1_prod[i][j]), .b(b1_fp32[i][j]), .result(mac1_fp32[i][j]));

                assign mac1_bf16[i][j] = fp32_to_bf16_round(mac1_fp32[i][j]);

                // GELU PWL LUTs
                bf16_LUT lut_idx (.data_in(mac1_bf16[i][j]), .data_out(gelu_idx[i][j]));
                gelu_LUT  lut_gelu (
                    .index_in(gelu_idx[i][j]),
                    .slope_out(gelu_slope_bf16[i][j]),
                    .intercept_out(gelu_intercept_bf16[i][j])
                );

                assign gelu_slope_fp32[i][j]     = bf16_to_fp32(gelu_slope_bf16[i][j]);
                assign gelu_intercept_fp32[i][j] = bf16_to_fp32(gelu_intercept_bf16[i][j]);
                assign gelu_in_fp32[i][j]         = bf16_to_fp32(mac1_bf16[i][j]);

                fp32_mul gelu_mul (.a(gelu_slope_fp32[i][j]), .b(gelu_in_fp32[i][j]), .result(gelu_mul_fp32[i][j]));
                fp32_add gelu_add (.a(gelu_mul_fp32[i][j]), .b(gelu_intercept_fp32[i][j]), .result(gelu_out_fp32[i][j]));

                assign gelu_bf16[i][j] = fp32_to_bf16_round(gelu_out_fp32[i][j]);

                // MAC2
                assign gelu_bf16_fp32[i][j] = bf16_to_fp32(gelu_bf16[i][j]);
                fp32_mul mac2_mul (.a(w2_fp32[i][j]), .b(gelu_bf16_fp32[i][j]), .result(mac2_prod[i][j]));
                fp32_add mac2_add (.a(mac2_prod[i][j]), .b(b2_fp32[i][j]), .result(mac2_fp32[i][j]));

                assign y_ref[i][j] = fp32_to_bf16_round(mac2_fp32[i][j]);
            end
        end
    endgenerate

endmodule

