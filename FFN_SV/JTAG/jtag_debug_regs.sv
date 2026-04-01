// JTAG Debug Scan Registers for FFN design
// Captures key internal signals into shift registers selectable by IR instruction.
// All captures are synchronised from the design clock (clk) domain to TCK domain.
module jtag_debug_regs #(
    parameter int N       = 2,
    parameter int IR_WIDTH = 4
)(
    // JTAG clock domain
    input  logic tck,
    input  logic trst_n,
    input  logic tdi,
    output logic tdo_dr,

    // TAP control
    input  logic shift_dr,
    input  logic capture_dr,
    input  logic update_dr,
    input  logic [IR_WIDTH-1:0] ir,

    // Design clock domain — observation signals (active on clk, captured on tck)
    input  logic clk,
    input  logic rst_n,

    // Control / status (active in design clock domain)
    input  logic       ready,
    input  logic       done,
    input  logic       ffn_start,
    input  logic       rx_dv,
    input  logic       tx_dv,
    input  logic       tx_busy,
    input  logic [2:0] wrapper_state,

    // FFN inputs
    input  var logic [15:0] w1_flat  [0:N*N-1],
    input  var logic [15:0] w2_flat  [0:N*N-1],
    input  var logic [15:0] x        [0:N-1],
    input  var logic [15:0] b1       [0:N-1],
    input  var logic [15:0] b2       [0:N-1],

    // FFN pipeline
    input  var logic [15:0] mac_out    [0:N-1],
    input  var logic [15:0] gelu_out   [0:N-1],
    input  var logic [15:0] mac_out_2  [0:N-1],
    input  var logic [15:0] y          [0:N-1],

    // JTAG → design: optional force-start (synchronised to clk by consumer)
    output logic        jtag_force_start,
    output logic        jtag_force_rst
);

    // =========================================================================
    // IR instruction encoding
    // =========================================================================
    localparam logic [IR_WIDTH-1:0] BYPASS       = 4'b1111;
    localparam logic [IR_WIDTH-1:0] IDCODE       = 4'b0001;
    localparam logic [IR_WIDTH-1:0] DBG_STATUS   = 4'b0010;  // 16 bits : control flags
    localparam logic [IR_WIDTH-1:0] DBG_FFN_IN   = 4'b0011;  // 224 bits: w1,w2,x,b1,b2
    localparam logic [IR_WIDTH-1:0] DBG_FFN_PIPE = 4'b0100;  // 128 bits: mac_out,gelu_out,mac_out_2,y
    localparam logic [IR_WIDTH-1:0] DBG_CONTROL  = 4'b0101;  //   2 bits: force_start, force_rst

    // =========================================================================
    // Widths
    // =========================================================================
    localparam int STATUS_W   = 16;
    localparam int FFN_IN_W   = (N*N + N*N + N + N + N) * 16;  // 224 for N=2
    localparam int FFN_PIPE_W = N*16 * 4;                       // 128 for N=2
    localparam int CONTROL_W  = 2;
    localparam int IDCODE_W   = 32;

    // =========================================================================
    // Clock-domain crossing: capture design signals into TCK domain
    // Two-stage synchroniser for each group (captured as a snapshot)
    // =========================================================================

    // Pack status bits in design clock domain
    logic [STATUS_W-1:0]   status_packed;
    logic [FFN_IN_W-1:0]   ffn_in_packed;
    logic [FFN_PIPE_W-1:0] ffn_pipe_packed;

    always_comb begin
        status_packed = '0;
        status_packed[0]   = ready;
        status_packed[1]   = done;
        status_packed[2]   = ffn_start;
        status_packed[3]   = rx_dv;
        status_packed[4]   = tx_dv;
        status_packed[5]   = tx_busy;
        status_packed[8:6] = wrapper_state;
    end

    always_comb begin
        ffn_in_packed = '0;
        for (int i = 0; i < N*N; i++)
            ffn_in_packed[i*16 +: 16] = w1_flat[i];
        for (int i = 0; i < N*N; i++)
            ffn_in_packed[(N*N + i)*16 +: 16] = w2_flat[i];
        for (int i = 0; i < N; i++)
            ffn_in_packed[(2*N*N + i)*16 +: 16] = x[i];
        for (int i = 0; i < N; i++)
            ffn_in_packed[(2*N*N + N + i)*16 +: 16] = b1[i];
        for (int i = 0; i < N; i++)
            ffn_in_packed[(2*N*N + 2*N + i)*16 +: 16] = b2[i];
    end

    always_comb begin
        ffn_pipe_packed = '0;
        for (int i = 0; i < N; i++) begin
            ffn_pipe_packed[i*16 +: 16]         = mac_out[i];
            ffn_pipe_packed[(N + i)*16 +: 16]   = gelu_out[i];
            ffn_pipe_packed[(2*N + i)*16 +: 16] = mac_out_2[i];
            ffn_pipe_packed[(3*N + i)*16 +: 16] = y[i];
        end
    end

    // Two-flop synchroniser (snapshot on tck)
    logic [STATUS_W-1:0]   status_sync1, status_sync2;
    logic [FFN_IN_W-1:0]   ffn_in_sync1, ffn_in_sync2;
    logic [FFN_PIPE_W-1:0] ffn_pipe_sync1, ffn_pipe_sync2;

    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            status_sync1   <= '0; status_sync2   <= '0;
            ffn_in_sync1   <= '0; ffn_in_sync2   <= '0;
            ffn_pipe_sync1 <= '0; ffn_pipe_sync2 <= '0;
        end else begin
            status_sync1   <= status_packed;   status_sync2   <= status_sync1;
            ffn_in_sync1   <= ffn_in_packed;   ffn_in_sync2   <= ffn_in_sync1;
            ffn_pipe_sync1 <= ffn_pipe_packed; ffn_pipe_sync2 <= ffn_pipe_sync1;
        end
    end

    // =========================================================================
    // Shift registers (all in TCK domain)
    // =========================================================================

    // --- IDCODE register (read-only, 32-bit) ---
    // Format: {version[31:28], part[27:12], manufacturer[11:1], 1'b1}
    localparam logic [31:0] IDCODE_VAL = 32'h1FF0_0001;
    logic [IDCODE_W-1:0] idcode_sr;

    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            idcode_sr <= IDCODE_VAL;
        else if (capture_dr && ir == IDCODE)
            idcode_sr <= IDCODE_VAL;
        else if (shift_dr && ir == IDCODE)
            idcode_sr <= {tdi, idcode_sr[IDCODE_W-1:1]};
    end

    // --- BYPASS register (mandatory, 1-bit) ---
    logic bypass_sr;

    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            bypass_sr <= 1'b0;
        else if (capture_dr && ir == BYPASS)
            bypass_sr <= 1'b0;
        else if (shift_dr && ir == BYPASS)
            bypass_sr <= tdi;
    end

    // --- STATUS register ---
    logic [STATUS_W-1:0] status_sr;

    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            status_sr <= '0;
        else if (capture_dr && ir == DBG_STATUS)
            status_sr <= status_sync2;
        else if (shift_dr && ir == DBG_STATUS)
            status_sr <= {tdi, status_sr[STATUS_W-1:1]};
    end

    // --- FFN_IN register ---
    logic [FFN_IN_W-1:0] ffn_in_sr;

    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            ffn_in_sr <= '0;
        else if (capture_dr && ir == DBG_FFN_IN)
            ffn_in_sr <= ffn_in_sync2;
        else if (shift_dr && ir == DBG_FFN_IN)
            ffn_in_sr <= {tdi, ffn_in_sr[FFN_IN_W-1:1]};
    end

    // --- FFN_PIPE register ---
    logic [FFN_PIPE_W-1:0] ffn_pipe_sr;

    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            ffn_pipe_sr <= '0;
        else if (capture_dr && ir == DBG_FFN_PIPE)
            ffn_pipe_sr <= ffn_pipe_sync2;
        else if (shift_dr && ir == DBG_FFN_PIPE)
            ffn_pipe_sr <= {tdi, ffn_pipe_sr[FFN_PIPE_W-1:1]};
    end

    // --- CONTROL register (write-only from JTAG → design) ---
    logic [CONTROL_W-1:0] ctrl_sr;
    logic [CONTROL_W-1:0] ctrl_reg;

    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            ctrl_sr <= '0;
        else if (capture_dr && ir == DBG_CONTROL)
            ctrl_sr <= ctrl_reg;
        else if (shift_dr && ir == DBG_CONTROL)
            ctrl_sr <= {tdi, ctrl_sr[CONTROL_W-1:1]};
    end

    always_ff @(posedge tck or negedge trst_n) begin
        if (!trst_n)
            ctrl_reg <= '0;
        else if (update_dr && ir == DBG_CONTROL)
            ctrl_reg <= ctrl_sr;
    end

    assign jtag_force_start = ctrl_reg[0];
    assign jtag_force_rst   = ctrl_reg[1];

    // =========================================================================
    // TDO mux — select which DR feeds TDO based on current IR
    // =========================================================================
    always_comb begin
        case (ir)
            IDCODE:       tdo_dr = idcode_sr[0];
            DBG_STATUS:   tdo_dr = status_sr[0];
            DBG_FFN_IN:   tdo_dr = ffn_in_sr[0];
            DBG_FFN_PIPE: tdo_dr = ffn_pipe_sr[0];
            DBG_CONTROL:  tdo_dr = ctrl_sr[0];
            default:      tdo_dr = bypass_sr;
        endcase
    end

endmodule
