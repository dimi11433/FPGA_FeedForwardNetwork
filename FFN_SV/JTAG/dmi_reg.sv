module dmi_reg (
    // JTAG clock domain
    input  logic        tck_i,
    input  logic        trst_ni,
    input  logic        capture_i,
    input  logic        shift_i,
    input  logic        update_i,
    input  logic        dmi_select_i,
    input  logic        tdi_i,

    // Reset commands from DTMCS
    input  logic        dmi_reset_i,
    input  logic        dmi_hard_reset_i,

    // Status back to DTMCS
    output logic [1:0]  dmi_stat_o,

    // Serial data out to TAP
    output logic        dmi_tdo_o,

    // Debug read ports — wired to FFN top module signals
    input  logic [15:0] y_i        [0:1][0:1],
    input  logic [15:0] mac_out_i  [0:1][0:1],
    input  logic [15:0] gelu_out_i [0:1][0:1],
    input  logic        ready1_i   [0:1],
    input  logic        ready2_i   [0:1]
);

    // -------------------------------------------------------
    // op encoding:
    //   2'b00 = noop
    //   2'b01 = read  — host reads data from address
    //   2'b10 = write — host writes data to address
    //   2'b11 = reserved
    //
    // dmi_stat encoding:
    //   2'b00 = success / no error
    //   2'b10 = op failed (bad address or illegal write)
    //   2'b11 = too fast / busy
    // -------------------------------------------------------

    logic [40:0] shift_reg;     // 41-bit shift register

    logic [6:0]  addr_q;        // latched address from last update
    logic [31:0] data_q;        // latched data from last update
    logic [1:0]  op_q;          // latched op from last update
    logic [1:0]  dmi_stat_q;    // sticky error status

    logic [31:0] read_data;     // mux output for current address
    logic        addr_valid;    // goes low if address is not in map

    // -------------------------------------------------------
    // Address decode — pick the right FFN signal
    // -------------------------------------------------------
    always_comb begin
        addr_valid = 1'b1;
        case (addr_q)
            7'h00: read_data = {16'h0, y_i[0][0]};
            7'h01: read_data = {16'h0, y_i[0][1]};
            7'h02: read_data = {16'h0, y_i[1][0]};
            7'h03: read_data = {16'h0, y_i[1][1]};
            7'h04: read_data = {16'h0, mac_out_i[0][0]};
            7'h05: read_data = {16'h0, mac_out_i[0][1]};
            7'h06: read_data = {16'h0, mac_out_i[0][1]};
            7'h07: read_data = {16'h0, mac_out_i[1][1]};
            7'h08: read_data = {16'h0, gelu_out_i[0][0]};
            7'h09: read_data = {16'h0, gelu_out_i[0][1]};
            7'h0A: read_data = {16'h0, gelu_out_i[1][0]};
            7'h0B: read_data = {16'h0, gelu_out_i[1][1]};
            7'h10: read_data = {28'h0, ready2_i[1], ready2_i[0],
                                       ready1_i[1], ready1_i[0]};
            default: begin
                read_data  = 32'hDEADBEEF;  // sentinel for unmapped address
                addr_valid = 1'b0;
            end
        endcase
    end

    // -------------------------------------------------------
    // Shift register — 3 phases, all on TCK
    // -------------------------------------------------------
    always_ff @(posedge tck_i or negedge trst_ni) begin
        if (!trst_ni || dmi_hard_reset_i) begin
            shift_reg <= 41'h0;
        end else if (capture_i && dmi_select_i) begin
            // Phase 1: load {address, read data from last op, status}
            shift_reg <= {addr_q, read_data, dmi_stat_q};
        end else if (shift_i && dmi_select_i) begin
            // Phase 2: shift right — LSB goes out TDO, new bit enters MSB from TDI
            shift_reg <= {tdi_i, shift_reg[40:1]};
        end
    end

    // TDO is always the current LSB
    assign dmi_tdo_o = shift_reg[0];

    // -------------------------------------------------------
    // Update phase — latch and execute the operation
    // -------------------------------------------------------
    always_ff @(posedge tck_i or negedge trst_ni) begin
        if (!trst_ni || dmi_hard_reset_i) begin
            addr_q     <= 7'h0;
            data_q     <= 32'h0;
            op_q       <= 2'b00;
            dmi_stat_q <= 2'b00;
        end else if (dmi_reset_i) begin
            dmi_stat_q <= 2'b00;    // DTMCS told us to clear sticky error
        end else if (update_i && dmi_select_i) begin
            // Unpack what the host shifted in
            addr_q <= shift_reg[40:34];
            data_q <= shift_reg[33:2];
            op_q   <= shift_reg[1:0];

            case (shift_reg[1:0])
                2'b01: begin    // read request
                    if (!addr_valid)
                        dmi_stat_q <= 2'b10;    // bad address — flag error
                    else
                        dmi_stat_q <= 2'b00;    // success
                end
                2'b10: begin    // write request — design is read-only
                    dmi_stat_q <= 2'b10;        // flag as op failed
                end
                default: ;      // noop — preserve status
            endcase
        end
    end

    assign dmi_stat_o = dmi_stat_q;

endmodule : dmi_reg
