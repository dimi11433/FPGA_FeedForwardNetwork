// =============================================================================
// MAC.sv
// Multiply-Accumulate unit for Q8.8 fixed-point arithmetic.
//   - Multiplies two Q8.8 signed inputs  -> 32-bit Q16.16 product
//   - Truncates back to Q8.8 (bits [23:8])
//   - Accumulates into a 16-bit register
// Replaces MAC.vhd
// =============================================================================

module MAC #(
    parameter int DATA_SIZE = 16,  // Q8.8 input width
    parameter int ACC_SIZE  = 16   // Q8.8 output width
) (
    input  logic                    clk,
    input  logic                    rst_n,   // Active-low async reset
    input  logic                    en,
    input  logic [DATA_SIZE-1:0]    data_in_a,
    input  logic [DATA_SIZE-1:0]    data_in_b,
    output logic [ACC_SIZE-1:0]     data_out
);

    // Full Q16.16 product
    logic signed [(DATA_SIZE*2)-1:0] product_full;

    // Q8.8 truncated product (bits 23 downto 8)
    logic signed [ACC_SIZE-1:0]      product_shifted;

    // Accumulator register
    logic signed [ACC_SIZE-1:0]      acc_reg;

    // ---- Combinational multiply ----
    assign product_full    = signed'(data_in_a) * signed'(data_in_b);
    assign product_shifted = product_full[23:8];

    // ---- Accumulate ----
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            acc_reg <= '0;
        else if (en)
            acc_reg <= acc_reg + product_shifted;
    end

    assign data_out = acc_reg;

endmodule : MAC
