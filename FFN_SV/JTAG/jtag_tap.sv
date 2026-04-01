// IEEE 1149.1 JTAG TAP Controller
// Standard 16-state FSM with configurable IR width
module jtag_tap #(
    parameter int IR_WIDTH = 4,
    parameter logic [IR_WIDTH-1:0] IR_RESET_VAL = '1   // BYPASS after reset
)(
    input  logic tck,
    input  logic tms,
    input  logic trst_n,
    input  logic tdi,
    output logic tdo,
    output logic tdo_en,

    // Decoded state strobes for external register logic
    output logic shift_dr,
    output logic capture_dr,
    output logic update_dr,
    output logic shift_ir,
    output logic capture_ir,
    output logic update_ir,

    output logic [IR_WIDTH-1:0] ir_out,
    output logic tap_reset
);

    typedef enum logic [3:0] {
        TLR       = 4'hF,
        RTI       = 4'hC,
        SEL_DR    = 4'h7,
        CAP_DR    = 4'h6,
        SH_DR     = 4'h2,
        EX1_DR    = 4'h1,
        PAU_DR    = 4'h3,
        EX2_DR    = 4'h0,
        UPD_DR    = 4'h5,
        SEL_IR    = 4'h4,
        CAP_IR    = 4'hE,
        SH_IR     = 4'hA,
        EX1_IR    = 4'h9,
        PAU_IR    = 4'hB,
        EX2_IR    = 4'h8,
        UPD_IR    = 4'hD
    } tap_state_t;

    tap_state_t state, next_state;

    // State register
    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            state <= TLR;
        else
            state <= next_state;
    end

    // Next-state logic (IEEE 1149.1 Table 6-1)
    always_comb begin
        case (state)
            TLR:    next_state = tms ? TLR    : RTI;
            RTI:    next_state = tms ? SEL_DR : RTI;
            SEL_DR: next_state = tms ? SEL_IR : CAP_DR;
            CAP_DR: next_state = tms ? EX1_DR : SH_DR;
            SH_DR:  next_state = tms ? EX1_DR : SH_DR;
            EX1_DR: next_state = tms ? UPD_DR : PAU_DR;
            PAU_DR: next_state = tms ? EX2_DR : PAU_DR;
            EX2_DR: next_state = tms ? UPD_DR : SH_DR;
            UPD_DR: next_state = tms ? SEL_DR : RTI;
            SEL_IR: next_state = tms ? TLR    : CAP_IR;
            CAP_IR: next_state = tms ? EX1_IR : SH_IR;
            SH_IR:  next_state = tms ? EX1_IR : SH_IR;
            EX1_IR: next_state = tms ? UPD_IR : PAU_IR;
            PAU_IR: next_state = tms ? EX2_IR : PAU_IR;
            EX2_IR: next_state = tms ? UPD_IR : SH_IR;
            UPD_IR: next_state = tms ? SEL_DR : RTI;
            default: next_state = TLR;
        endcase
    end

    // Instruction register
    logic [IR_WIDTH-1:0] ir_shift;

    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            ir_shift <= '0;
        else if (state == CAP_IR)
            ir_shift <= {{(IR_WIDTH-2){1'b0}}, 2'b01};   // IEEE 1149.1 capture value
        else if (state == SH_IR)
            ir_shift <= {tdi, ir_shift[IR_WIDTH-1:1]};
    end

    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            ir_out <= IR_RESET_VAL;
        else if (state == UPD_IR)
            ir_out <= ir_shift;
    end

    // State decode outputs
    assign shift_dr   = (state == SH_DR);
    assign capture_dr = (state == CAP_DR);
    assign update_dr  = (state == UPD_DR);
    assign shift_ir   = (state == SH_IR);
    assign capture_ir = (state == CAP_IR);
    assign update_ir  = (state == UPD_IR);
    assign tap_reset  = (state == TLR);

    // TDO mux: IR shift register during Shift-IR, external DR during Shift-DR
    logic tdo_ir;
    assign tdo_ir = ir_shift[0];

    // TDO and enable driven on falling edge for hold-time compliance
    always_ff @(negedge tck or negedge trst_n) begin
        if (!trst_n) begin
            tdo    <= 1'b0;
            tdo_en <= 1'b0;
        end else begin
            tdo_en <= (state == SH_DR) || (state == SH_IR);
            tdo    <= (state == SH_IR) ? tdo_ir : 1'b0;  // DR TDO injected externally
        end
    end

endmodule
