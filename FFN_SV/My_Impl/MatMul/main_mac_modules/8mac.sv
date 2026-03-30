`include "fp32_mul.sv"
`include "fp32_add.sv"

module mac8 #(parameter N = 2)(
    input clk,
    input rst_n,
    input [15:0] data_in_a [0: N-1],
    input [15:0] data_in_b [0: N-1],
    input [15:0] data_in_c,
    output logic ready,
    output logic [15:0] data_out
);

    genvar i;
    logic [31:0] a_fp32 [0:N-1];
    logic [31:0] b_fp32 [0:N-1];
    logic [31:0] c_fp32;
    logic [31:0] prod_fp32 [0:N-1];
    logic [31:0] sum_chain [0:N];
    logic [31:0] out_fp32;

    assign c_fp32 = {data_in_c, 16'h0000};
    assign sum_chain[0] = 32'h0000_0000;

    generate
        for (i = 0; i < N; i = i + 1) begin : gen_dot
            assign a_fp32[i] = {data_in_a[i], 16'h0000};
            assign b_fp32[i] = {data_in_b[i], 16'h0000};
            fp32_mul mul_i (.a(a_fp32[i]), .b(b_fp32[i]), .result(prod_fp32[i]));
            fp32_add add_i (.a(sum_chain[i]), .b(prod_fp32[i]), .result(sum_chain[i+1]));
        end
    endgenerate

    fp32_add add_bias (.a(sum_chain[N]), .b(c_fp32), .result(out_fp32));

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            data_out <= 16'h0000;
            ready    <= 1'b0;
        end else begin
            data_out <= (out_fp32[15] && out_fp32[31:16] != 16'hFFFF)
                ? (out_fp32[31:16] + 16'd1) : out_fp32[31:16];
            ready <= 1'b1;
        end
    end

    
endmodule