`include "fp32_mul.sv"
`include "fp32_add.sv"

// Cleaned-up version of `mac_8cyc`:
// - Uses fp32_mul / fp32_add *outputs* as combinational wires
// - Accumulates only inside the clocked always_ff (single driver for intermediate_out)
module mac_8cyc_v2(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [15:0] data_in_a,
    input  logic [15:0] data_in_b,
    input  logic [15:0] data_in_c,
    output logic        ready,
    output logic [15:0] data_out
);
    // Latched accumulator (your original used 32-bit and then took [31:16])
    logic [31:0] intermediate_out;
    logic [4:0]  cycle_count;

    // Build FP32-ish operands from the 16-bit inputs (kept identical to original)
    logic [31:0] W1_fp32, x_fp32, b_fp32;
    assign W1_fp32 = {data_in_a, 16'h0000};
    assign x_fp32  = {data_in_b, 16'h0000};
    assign b_fp32  = {data_in_c, 16'h0000};

    // Combinational multiplier output
    logic [31:0] prod_fp32;
    fp32_mul mul_inst (
        .a(W1_fp32),
        .b(x_fp32),
        .result(prod_fp32)
    );

    // Choose what to add this cycle:
    // - cycle_count < 8  -> add prod_fp32
    // - cycle_count == 8 -> add b_fp32
    logic [31:0] rhs_fp32;
    assign rhs_fp32 = (cycle_count == 5'd8) ? b_fp32 : prod_fp32;

    // Combinational adder output based on current accumulator + rhs
    logic [31:0] sum_fp32;
    fp32_add add_inst (
        .a(intermediate_out),
        .b(rhs_fp32),
        .result(sum_fp32)
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ready            <= 1'b0;
            data_out         <= 16'h0000;
            intermediate_out <= 32'h00000000;
            cycle_count      <= 5'd0;
        end else begin
            if (cycle_count < 5'd8) begin
                cycle_count      <= cycle_count + 5'd1;
                intermediate_out <= sum_fp32;
                ready            <= 1'b0; // make it a pulse
            end else if (cycle_count == 5'd8) begin
                cycle_count      <= cycle_count + 5'd1;
                intermediate_out <= sum_fp32; // sum_fp32 used with rhs_fp32=b_fp32
                ready            <= 1'b0; // make it a pulse
            end else begin
                // cycle_count == 9: output previous accumulated value
                ready       <= 1'b1;
                cycle_count <= 5'd0;
                data_out    <= intermediate_out[31:16];
            end
        end
    end

endmodule

