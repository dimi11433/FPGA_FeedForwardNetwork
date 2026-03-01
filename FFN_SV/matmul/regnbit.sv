// =============================================================================
// regnbit.sv
// Parameterized N-bit register with synchronous enable and active-low async reset.
// Replaces regnbit.vhd
// =============================================================================

module regnbit #(
    parameter int N = 16
) (
    input  logic            clk,
    input  logic            rst_n,  // Active-low asynchronous reset
    input  logic            en,
    input  logic [N-1:0]    d,
    output logic [N-1:0]    q
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= '0;
        else if (en)
            q <= d;
    end

endmodule : regnbit
