// =============================================================================
// mux_2to1_nbit.sv
// Parameterized 2-to-1 multiplexer.
// Replaces mux_2to1_nbit_base.vhd
// =============================================================================

module mux_2to1_nbit #(
    parameter int N = 16
) (
    input  logic [N-1:0] i0,
    input  logic [N-1:0] i1,
    input  logic         sel,
    output logic [N-1:0] y
);

    always_comb begin
        unique case (sel)
            1'b0:    y = i0;
            1'b1:    y = i1;
            default: y = '0;
        endcase
    end

endmodule : mux_2to1_nbit
