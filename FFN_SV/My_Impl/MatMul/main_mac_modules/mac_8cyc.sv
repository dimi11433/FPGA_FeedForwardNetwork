// mac_8cyc: single lane MAC. Parameter N_ACCUM = number of product accumulations before adding bias.
// For element-wise (a*b+c): N_ACCUM=1. For dot-product of length N: N products then bias.
// BUG FIX: rhs_fp32 used cycle_count==8 (for N=8) but cycle_count never reached 8 when N=2,
// so bias was never added and we kept adding prod_reg → 2x to 8x error.
module mac_8cyc #(parameter N_ACCUM = 1)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [15:0] data_in_a,
    input  logic [15:0] data_in_b,
    input  logic [15:0] data_in_c,
    output logic        ready,
    output logic [15:0] data_out
);
    logic [31:0] intermediate_out;
    logic [4:0]  cycle_count;

    logic [31:0] W1_fp32, x_fp32, b_fp32;
    assign W1_fp32 = {data_in_a, 16'h0000};
    assign x_fp32  = {data_in_b, 16'h0000};
    assign b_fp32  = {data_in_c, 16'h0000};

    logic [31:0] prod_fp32;
    fp32_mul mul_inst (.a(W1_fp32), .b(x_fp32), .result(prod_fp32));

    // Add bias on cycle N_ACCUM, else add product
    logic [31:0] rhs_fp32;
    assign rhs_fp32 = (cycle_count == N_ACCUM) ? b_fp32 : prod_fp32;

    logic [31:0] sum_fp32;
    fp32_add add_inst (.a(intermediate_out), .b(rhs_fp32), .result(sum_fp32));

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ready            <= 1'b0;
            data_out         <= 16'h0000;
            intermediate_out <= 32'h00000000;
            cycle_count      <= 5'd0;
        end else begin
            if (cycle_count <= N_ACCUM) begin
                // Cycles 0..N_ACCUM-1: add product; cycle N_ACCUM: add bias
                cycle_count      <= cycle_count + 5'd1;
                intermediate_out <= sum_fp32;
                ready            <= 1'b0; // deassert while accumulating
            end else begin
                // cycle_count == N_ACCUM+1: output
                ready       <= 1'b1;
                cycle_count <= 5'd0;
                data_out    <= (intermediate_out[15] && intermediate_out[31:16] != 16'hFFFF)
                    ? (intermediate_out[31:16] + 16'd1) : intermediate_out[31:16];
                // Important: clear accumulator so next run doesn't keep accumulating.
                // RHS of data_out uses the old intermediate_out value (nonblocking).
                intermediate_out <= 32'h00000000;
            end
        end
    end

endmodule

