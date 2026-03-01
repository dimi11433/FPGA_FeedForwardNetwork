// =============================================================================
// ff.sv
// Single-bit D flip-flop with synchronous enable and active-low async reset.
// Replaces ff.vhd
// =============================================================================

module ff (
    input  logic clk,
    input  logic rst_n,   // Active-low asynchronous reset
    input  logic en,
    input  logic d,
    output logic q
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= 1'b0;
        else if (en)
            q <= d;
    end

endmodule : ff
