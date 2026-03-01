// =============================================================================
// mux_4to1_nbit.sv
// Parameterized 4-to-1 multiplexer.
// Replaces mux_4to1_nbit_base.vhd
// =============================================================================

module mux_4to1_nbit #(
    parameter int N = 16
) (
    input  logic [N-1:0] i0,
    input  logic [N-1:0] i1,
    input  logic [N-1:0] i2,
    input  logic [N-1:0] i3,
    input  logic [1:0]   sel,
    output logic [N-1:0] y
);

    always_comb begin
        unique case (sel)
            2'b00:   y = i0;
            2'b01:   y = i1;
            2'b10:   y = i2;
            2'b11:   y = i3;
            default: y = '0;
        endcase
    end

endmodule : mux_4to1_nbit
