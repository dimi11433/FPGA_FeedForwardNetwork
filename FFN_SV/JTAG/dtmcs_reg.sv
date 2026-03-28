module dtmcs_reg ( 
    input logic tck_i,
    input logic trst_ni,
    input logic capture_i,
    input logic shift_i,
    input logic update_i,
    input logic dtmcs_select_i,
    input logic tdi_i,
    input logic [1:0] dmi_stat_i,
    output logic dtmcs_tdo_o,
    output logic dmi_reset_o,
    output logic dmi_hard_reset_o
);

    // The full DTMCS value (hardcoded fields assembled)
    // [31:18]=0, [17]=dmihardreset(W), [16]=dmireset(W),
    // [15]=0, [14:12]=idle=1, [11:10]=dmistat, [9:4]=abits=7, [3:0]=version=1
    logic [31:0] dtmcs_d, dtmcs_q;   // captured/latched value
    logic [31:0] shift_reg;           // the shift register

    // Assemble the read value from hardcoded fields + live dmi_stat_i
    wire [31:0] dtmcs_status = {
        14'h0,        // [31:18] reserved
        1'b0,         // [17]    dmihardreset (write-only, reads as 0)
        1'b0,         // [16]    dmireset     (write-only, reads as 0)
        1'b0,         // [15]    reserved
        3'h1,         // [14:12] idle = 1 cycle
        dmi_stat_i,   // [11:10] dmistat (live from DMI)
        6'h07,        // [9:4]   abits = 7
        4'h1          // [3:0]   version = 1 (spec 0.13)
    };

    // Shift register — operates on TCK
    always_ff @(posedge tck_i or negedge trst_ni) begin
        if (!trst_ni) begin
            shift_reg <= 32'h0;
        end else if (capture_i && dtmcs_select_i) begin
            shift_reg <= dtmcs_status;   // Phase 1: load current status
        end else if (shift_i && dtmcs_select_i) begin
            shift_reg <= {tdi_i, shift_reg[31:1]};  // Phase 2: shift right, LSB out
        end
    end

    // TDO is always the LSB of the shift register
    assign dtmcs_tdo_o = shift_reg[0];

    // Update phase — latch what the host wrote
    always_ff @(posedge tck_i or negedge trst_ni) begin
        if (!trst_ni) begin
            dtmcs_q <= 32'h0;
        end else if (update_i && dtmcs_select_i) begin
            dtmcs_q <= shift_reg;   // Phase 3: latch the shifted-in value
        end
    end

    // Drive reset outputs based on what the host wrote
    // These are level signals — pulse for one TCK cycle after update
    assign dmi_reset_o      = dtmcs_q[16];
    assign dmi_hard_reset_o = dtmcs_q[17];

endmodule : dtmcs_reg