// dtmcs_reg.sv
// Debug Transport Module Control and Status register
// Read-only status snapshot of the Q8.8 datapath

module dtmcs_reg #(parameter N = 2) (
    input  logic        clk,
    input  logic        rst_n,

    // Status inputs from top.sv
    input  logic        ready1 [0:N-1][0:N-1],
    input  logic        ready2 [0:N-1][0:N-1],
    input  logic [15:0] y      [0:N-1][0:N-1],

    // Readable status word (32-bit) — read by dmi_jtag via dtmcs_tdo_i
    output logic [31:0] dtmcs_status
);

    // Pack status into a 32-bit word:
    // [31:16] = y[0][0] (final output snapshot)
    // [3:0]   = ready1 flags
    // [7:4]   = ready2 flags
    // [15:8]  = reserved/zero

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dtmcs_status <= 32'h0;
        end else begin
            dtmcs_status <= {
                y[0][0],               // [31:16] output snapshot
                4'h0,                  // [15:12] reserved
                4'h0,                  // [11:8]  reserved
                ready2[1][1], ready2[1][0],
                ready2[0][1], ready2[0][0],  // [7:4]
                ready1[1][1], ready1[1][0],
                ready1[0][1], ready1[0][0]   // [3:0]
            };
        end
    end

endmodule
