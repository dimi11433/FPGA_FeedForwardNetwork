// =============================================================================
// bias_sum_8_8.sv
// Adds a single bias value (b_col) to all 8 input rows combinationally.
// Operates on Q8.8 signed values.
// Replaces bias_sum_8_8.vhd
// =============================================================================

module bias_sum_8_8 (
    input  logic signed [15:0] input_row [0:7],
    input  logic signed [15:0] b_col,
    output logic signed [15:0] output_row [0:7]
);

    always_comb begin
        for (int i = 0; i < 8; i++) begin
            output_row[i] = input_row[i] + b_col;
        end
    end

endmodule : bias_sum_8_8
