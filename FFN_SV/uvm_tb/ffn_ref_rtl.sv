`include "fp32_mul.sv"
`include "fp32_add.sv"
`include "bf16_LUT.sv"
`include "gelu-LUT.sv"

// RTL-accurate combinational reference for top.sv (vector FFN form):
// y = W2 * GELU(W1*x + b1) + b2
module ffn_ref_rtl #(parameter int N = 2) (
    input  logic [15:0] w2 [0:N-1][0:N-1],
    input  logic [15:0] w1 [0:N-1][0:N-1],
    input  logic [15:0] b1 [0:N-1],
    input  logic [15:0] b2 [0:N-1],
    input  logic [15:0] x  [0:N-1],
    output logic [15:0] y_ref [0:N-1]
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

    logic [31:0] x_fp32   [0:N-1];
    logic [31:0] b1_fp32  [0:N-1];
    logic [31:0] b2_fp32  [0:N-1];
    logic [31:0] w1_fp32  [0:N-1][0:N-1];
    logic [31:0] w2_fp32  [0:N-1][0:N-1];

    logic [31:0] mac1_prod [0:N-1][0:N-1];
    logic [31:0] mac1_sum  [0:N-1][0:N];
    logic [31:0] mac1_fp32 [0:N-1];
    logic [15:0] mac1_bf16 [0:N-1];

    logic [4:0]  gelu_idx [0:N-1];
    logic [15:0] gelu_slope_bf16     [0:N-1];
    logic [15:0] gelu_intercept_bf16 [0:N-1];
    logic [31:0] gelu_slope_fp32     [0:N-1];
    logic [31:0] gelu_intercept_fp32 [0:N-1];
    logic [31:0] gelu_in_fp32        [0:N-1];
    logic [31:0] gelu_mul_fp32       [0:N-1];
    logic [31:0] gelu_out_fp32       [0:N-1];
    logic [15:0] hidden_bf16         [0:N-1];
    logic [31:0] hidden_fp32         [0:N-1];

    logic [31:0] mac2_prod [0:N-1][0:N-1];
    logic [31:0] mac2_sum  [0:N-1][0:N];
    logic [31:0] mac2_fp32 [0:N-1];

    genvar i, j;
    generate
        for (j = 0; j < N; j++) begin : gen_common_inputs
            assign x_fp32[j]  = bf16_to_fp32(x[j]);
            assign b1_fp32[j] = bf16_to_fp32(b1[j]);
            assign b2_fp32[j] = bf16_to_fp32(b2[j]);
        end

        for (i = 0; i < N; i++) begin : gen_layer1
            assign mac1_sum[i][0] = 32'h0000_0000;
            for (j = 0; j < N; j++) begin : gen_layer1_dot
                assign w1_fp32[i][j] = bf16_to_fp32(w1[i][j]);
                fp32_mul mac1_mul (.a(w1_fp32[i][j]), .b(x_fp32[j]), .result(mac1_prod[i][j]));
                fp32_add mac1_add (.a(mac1_sum[i][j]), .b(mac1_prod[i][j]), .result(mac1_sum[i][j+1]));
            end
            fp32_add mac1_bias (.a(mac1_sum[i][N]), .b(b1_fp32[i]), .result(mac1_fp32[i]));
            assign mac1_bf16[i] = fp32_to_bf16_round(mac1_fp32[i]);

            bf16_LUT lut_idx (.data_in(mac1_bf16[i]), .data_out(gelu_idx[i]));
            gelu_LUT lut_gelu (
                .index_in(gelu_idx[i]),
                .slope_out(gelu_slope_bf16[i]),
                .intercept_out(gelu_intercept_bf16[i])
            );

            assign gelu_slope_fp32[i]     = bf16_to_fp32(gelu_slope_bf16[i]);
            assign gelu_intercept_fp32[i] = bf16_to_fp32(gelu_intercept_bf16[i]);
            assign gelu_in_fp32[i]        = bf16_to_fp32(mac1_bf16[i]);
            fp32_mul gelu_mul (.a(gelu_slope_fp32[i]), .b(gelu_in_fp32[i]), .result(gelu_mul_fp32[i]));
            fp32_add gelu_add (.a(gelu_mul_fp32[i]), .b(gelu_intercept_fp32[i]), .result(gelu_out_fp32[i]));
            assign hidden_bf16[i] = fp32_to_bf16_round(gelu_out_fp32[i]);
            assign hidden_fp32[i] = bf16_to_fp32(hidden_bf16[i]);
        end

        for (i = 0; i < N; i++) begin : gen_layer2
            assign mac2_sum[i][0] = 32'h0000_0000;
            for (j = 0; j < N; j++) begin : gen_layer2_dot
                assign w2_fp32[i][j] = bf16_to_fp32(w2[i][j]);
                fp32_mul mac2_mul (.a(w2_fp32[i][j]), .b(hidden_fp32[j]), .result(mac2_prod[i][j]));
                fp32_add mac2_add (.a(mac2_sum[i][j]), .b(mac2_prod[i][j]), .result(mac2_sum[i][j+1]));
            end
            fp32_add mac2_bias (.a(mac2_sum[i][N]), .b(b2_fp32[i]), .result(mac2_fp32[i]));
            assign y_ref[i] = fp32_to_bf16_round(mac2_fp32[i]);
        end
    endgenerate

endmodule

