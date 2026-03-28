/* Copyright 2018 ETH Zurich and University of Bologna.
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the “License”); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * File:   dmi_jtag_tap.sv
 * Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
 * Date:   19.7.2018
 *
 * Description: JTAG TAP for DMI (according to debug spec 0.13)
 *
 */

module dmi_jtag_tap #(
  parameter int unsigned IrLength = 5,
  // JTAG IDCODE Value
  parameter logic [31:0] IdcodeValue = 32'h00000001
  // xxxx             version
  // xxxxxxxxxxxxxxxx part number
  // xxxxxxxxxxx      manufacturer id
  // 1                required by standard
) (
  input  logic        tck_i,    // JTAG test clock pad
  input  logic        tms_i,    // JTAG test mode select pad
  input  logic        trst_ni,  // JTAG test reset pad
  input  logic        td_i,     // JTAG test data input pad
  output logic        td_o,     // JTAG test data output pad
  output logic        tdo_oe_o, // Data out output enable
  input  logic        testmode_i,
  // JTAG is interested in writing the DTM CSR register
  output logic        tck_o,
  // Synchronous reset of the dmi module triggered by JTAG TAP
  output logic        dmi_clear_o,
  output logic        update_o,
  output logic        capture_o,
  output logic        shift_o,
  output logic        tdi_o,
  output logic        dtmcs_select_o,
  input  logic        dtmcs_tdo_i,
  // we want to access DMI register
  output logic        dmi_select_o,
  input  logic        dmi_tdo_i
);

  typedef enum logic [3:0] {
    TestLogicReset, RunTestIdle, SelectDrScan,
    CaptureDr, ShiftDr, Exit1Dr, PauseDr, Exit2Dr,
    UpdateDr, SelectIrScan, CaptureIr, ShiftIr,
    Exit1Ir, PauseIr, Exit2Ir, UpdateIr
  } tap_state_e;

  tap_state_e tap_state_q, tap_state_d;
  logic update_dr, shift_dr, capture_dr;

  typedef enum logic [IrLength-1:0] {
    BYPASS0   = 'h0,
    IDCODE    = 'h1,
    DTMCSR    = 'h10,
    DMIACCESS = 'h11,
    BYPASS1   = 'h1f
  } ir_reg_e;

  // ----------------
  // IR logic
  // ----------------

  // shift register
  logic [IrLength-1:0]  jtag_ir_shift_d, jtag_ir_shift_q;
  // IR register -> this gets captured from shift register upon update_ir
  ir_reg_e              jtag_ir_d, jtag_ir_q;
  logic capture_ir, shift_ir, update_ir, test_logic_reset; // pause_ir

  always_comb begin : p_jtag
    jtag_ir_shift_d = jtag_ir_shift_q;
    jtag_ir_d       = jtag_ir_q;

    // IR shift register
    if (shift_ir) begin
      jtag_ir_shift_d = {td_i, jtag_ir_shift_q[IrLength-1:1]};
    end

    // capture IR register
    if (capture_ir) begin
      jtag_ir_shift_d =  IrLength'(4'b0101);
    end

    // update IR register
    if (update_ir) begin
      jtag_ir_d = ir_reg_e'(jtag_ir_shift_q);
    end

    if (test_logic_reset) begin
      // Bring all TAP state to the initial value.
      jtag_ir_shift_d = '0;
      jtag_ir_d = IDCODE;
    end
  end

  always_ff @(posedge tck_i, negedge trst_ni) begin : p_jtag_ir_reg
    if (!trst_ni) begin
      jtag_ir_shift_q <= '0;
      jtag_ir_q       <= IDCODE;
    end else begin
      jtag_ir_shift_q <= jtag_ir_shift_d;
      jtag_ir_q       <= jtag_ir_d;
    end
  end

  // ----------------
  // TAP DR Regs
  // ----------------
  // - Bypass
  // - IDCODE
  // - DTM CS
  logic [31:0] idcode_d, idcode_q;
  logic        idcode_select;
  logic        bypass_select;

  logic        bypass_d, bypass_q;  // this is a 1-bit register

  always_comb begin
    idcode_d = idcode_q;
    bypass_d = bypass_q;

    if (capture_dr) begin
      if (idcode_select) idcode_d = IdcodeValue;
      if (bypass_select) bypass_d = 1'b0;
    end

    if (shift_dr) begin
      if (idcode_select)  idcode_d = {td_i, 31'(idcode_q >> 1)};
      if (bypass_select)  bypass_d = td_i;
    end

    if (test_logic_reset) begin
      // Bring all TAP state to the initial value.
      idcode_d = IdcodeValue;
      bypass_d = 1'b0;
    end
  end

  // ----------------
  // Data reg select
  // ----------------
  always_comb begin : p_data_reg_sel
    dmi_select_o   = 1'b0;
    dtmcs_select_o = 1'b0;
    idcode_select  = 1'b0;
    bypass_select  = 1'b0;
    unique case (jtag_ir_q)
      BYPASS0:   bypass_select  = 1'b1;
      IDCODE:    idcode_select  = 1'b1;
      DTMCSR:    dtmcs_select_o = 1'b1;
      DMIACCESS: dmi_select_o   = 1'b1;
      BYPASS1:   bypass_select  = 1'b1;
      default:   bypass_select  = 1'b1;
    endcase
  end

  // ----------------
  // Output select
  // ----------------
  logic tdo_mux;

  always_comb begin : p_out_sel
    // we are shifting out the IR register
    if (shift_ir) begin
      tdo_mux = jtag_ir_shift_q[0];
    // here we are shifting the DR register
    end else begin
      unique case (jtag_ir_q)
        IDCODE:         tdo_mux = idcode_q[0];   // Reading ID code
        DTMCSR:         tdo_mux = dtmcs_tdo_i;   // Read from DTMCS TDO
        DMIACCESS:      tdo_mux = dmi_tdo_i;     // Read from DMI TDO
        default:        tdo_mux = bypass_q;      // BYPASS instruction
      endcase
    end
  end

  // ----------------
  // DFT — simplified for FPGA testing
  // tc_clk_inverter and tc_clk_mux2 replaced with direct assigns
  // ----------------
  logic tck_n, tck_ni;

  assign tck_ni = ~tck_i;
  assign tck_n  = testmode_i ? tck_i : tck_ni;



  // TDO changes state at negative edge of TCK
  always_ff @(posedge tck_n, negedge trst_ni) begin : p_tdo_regs
    if (!trst_ni) begin
      td_o     <= 1'b0;
      tdo_oe_o <= 1'b0;
    end else begin
      td_o     <= tdo_mux;
      tdo_oe_o <= (shift_ir | shift_dr);
    end
  end
  // ----------------
  // TAP FSM
  // ----------------
  // Determination of next state; purely combinatorial
  always_comb begin : p_tap_fsm

    test_logic_reset   = 1'b0;

    capture_dr         = 1'b0;
    shift_dr           = 1'b0;
    update_dr          = 1'b0;

    capture_ir         = 1'b0;
    shift_ir           = 1'b0;
    // pause_ir           = 1'b0; unused
    update_ir          = 1'b0;

    unique case (tap_state_q)
      TestLogicReset: begin
        tap_state_d = (tms_i) ? TestLogicReset : RunTestIdle;
        test_logic_reset = 1'b1;
      end
      RunTestIdle: begin
        tap_state_d = (tms_i) ? SelectDrScan : RunTestIdle;
      end
      // DR Path
      SelectDrScan: begin
        tap_state_d = (tms_i) ? SelectIrScan : CaptureDr;
      end
      CaptureDr: begin
        capture_dr = 1'b1;
        tap_state_d = (tms_i) ? Exit1Dr : ShiftDr;
      end
      ShiftDr: begin
        shift_dr = 1'b1;
        tap_state_d = (tms_i) ? Exit1Dr : ShiftDr;
      end
      Exit1Dr: begin
        tap_state_d = (tms_i) ? UpdateDr : PauseDr;
      end
      PauseDr: begin
        tap_state_d = (tms_i) ? Exit2Dr : PauseDr;
      end
      Exit2Dr: begin
        tap_state_d = (tms_i) ? UpdateDr : ShiftDr;
      end
      UpdateDr: begin
        update_dr = 1'b1;
        tap_state_d = (tms_i) ? SelectDrScan : RunTestIdle;
      end
      // IR Path
      SelectIrScan: begin
        tap_state_d = (tms_i) ? TestLogicReset : CaptureIr;
      end
      // In this controller state, the shift register bank in the
      // Instruction Register parallel loads a pattern of fixed values on
      // the rising edge of TCK. The last two significant bits must always
      // be "01".
      CaptureIr: begin
        capture_ir = 1'b1;
        tap_state_d = (tms_i) ? Exit1Ir : ShiftIr;
      end
      // In this controller state, the instruction register gets connected
      // between TDI and TDO, and the captured pattern gets shifted on
      // each rising edge of TCK. The instruction available on the TDI
      // pin is also shifted in to the instruction register.
      ShiftIr: begin
        shift_ir = 1'b1;
        tap_state_d = (tms_i) ? Exit1Ir : ShiftIr;
      end
      Exit1Ir: begin
        tap_state_d = (tms_i) ? UpdateIr : PauseIr;
      end
      PauseIr: begin
        // pause_ir = 1'b1; // unused
        tap_state_d = (tms_i) ? Exit2Ir : PauseIr;
      end
      Exit2Ir: begin
        tap_state_d = (tms_i) ? UpdateIr : ShiftIr;
      end
      // In this controller state, the instruction in the instruction
      // shift register is latched to the latch bank of the Instruction
      // Register on every falling edge of TCK. This instruction becomes
      // the current instruction once it is latched.
      UpdateIr: begin
        update_ir = 1'b1;
        tap_state_d = (tms_i) ? SelectDrScan : RunTestIdle;
      end
      default: ; // can't actually happen since case is full
    endcase
  end

  always_ff @(posedge tck_i or negedge trst_ni) begin : p_regs
    if (!trst_ni) begin
      tap_state_q <= TestLogicReset;
      idcode_q    <= IdcodeValue;
      bypass_q    <= 1'b0;
    end else begin
      tap_state_q <= tap_state_d;
      idcode_q    <= idcode_d;
      bypass_q    <= bypass_d;
    end
  end

  // Pass through JTAG signals to debug custom DR logic.
  // In case of a single TAP those are just feed-through.
  assign tck_o = tck_i;
  assign tdi_o = td_i;
  assign update_o = update_dr;
  assign shift_o = shift_dr;
  assign capture_o = capture_dr;
  assign dmi_clear_o = test_logic_reset;


endmodule : dmi_jtag_tap






// ============================================================
// MODULE 2: dmi_jtag
// ============================================================

module dmi_jtag #(
  parameter logic [31:0] IdcodeValue = 32'h00000DB3
) (
  input  logic         clk_i,
  input  logic         rst_ni,
  input  logic         testmode_i,

  output logic         dmi_rst_no,
  output dm::dmi_req_t dmi_req_o,
  output logic         dmi_req_valid_o,
  input  logic         dmi_req_ready_i,

  input  dm::dmi_resp_t dmi_resp_i,
  output logic          dmi_resp_ready_o,
  input  logic          dmi_resp_valid_i,

  input  logic         tck_i,
  input  logic         tms_i,
  input  logic         trst_ni,
  input  logic         td_i,
  output logic         td_o,
  output logic         tdo_oe_o
);

  typedef enum logic [1:0] {
    DMINoError = 2'h0, DMIReservedError = 2'h1,
    DMIOPFailed = 2'h2, DMIBusy = 2'h3
  } dmi_error_e;
  dmi_error_e error_d, error_q;

  logic tck;
  logic jtag_dmi_clear;
  logic dmi_clear;
  logic update;
  logic capture;
  logic shift;
  logic tdi;

  logic dtmcs_select;

  dm::dtmcs_t dtmcs_d, dtmcs_q;

  assign dmi_clear = jtag_dmi_clear || (dtmcs_select && update && dtmcs_q.dmihardreset);

  always_comb begin
    dtmcs_d = dtmcs_q;
    if (capture) begin
      if (dtmcs_select) begin
        dtmcs_d = '{
                    zero1        : '0,
                    dmihardreset : 1'b0,
                    dmireset     : 1'b0,
                    zero0        : '0,
                    idle         : 3'd1,
                    dmistat      : error_q,
                    abits        : 6'd7,
                    version      : 4'd1
                  };
      end
    end
    if (shift) begin
      if (dtmcs_select) dtmcs_d = {tdi, 31'(dtmcs_q >> 1)};
    end
  end

  always_ff @(posedge tck or negedge trst_ni) begin
    if (!trst_ni) begin
      dtmcs_q <= '0;
    end else begin
      dtmcs_q <= dtmcs_d;
    end
  end

  logic        dmi_select;
  logic        dmi_tdo;

  dm::dmi_req_t  dmi_req;
  logic          dmi_req_ready;
  logic          dmi_req_valid;

  dm::dmi_resp_t dmi_resp;
  logic          dmi_resp_valid;
  logic          dmi_resp_ready;

  typedef struct packed {
    logic [6:0]  address;
    logic [31:0] data;
    logic [1:0]  op;
  } dmi_t;

  typedef enum logic [2:0] {
    Idle, Read, WaitReadValid, Write, WaitWriteValid
  } state_e;
  state_e state_d, state_q;

  logic [$bits(dmi_t)-1:0] dr_d, dr_q;
  logic [6:0]  address_d, address_q;
  logic [31:0] data_d, data_q;

  dmi_t dmi;
  assign dmi          = dmi_t'(dr_q);
  assign dmi_req.addr = address_q;
  assign dmi_req.data = data_q;
  assign dmi_req.op   = (state_q == Write) ? dm::DTM_WRITE : dm::DTM_READ;
  assign dmi_resp_ready = 1'b1;

  logic error_dmi_busy;
  logic error_dmi_op_failed;

  always_comb begin : p_fsm
    error_dmi_busy      = 1'b0;
    error_dmi_op_failed = 1'b0;
    state_d   = state_q;
    address_d = address_q;
    data_d    = data_q;
    error_d   = error_q;
    dmi_req_valid = 1'b0;

    if (dmi_clear) begin
      state_d   = Idle;
      data_d    = '0;
      error_d   = DMINoError;
      address_d = '0;
    end else begin
      unique case (state_q)
        Idle: begin
          if (dmi_select && update && (error_q == DMINoError)) begin
            address_d = dmi.address;
            data_d    = dmi.data;
            if (dm::dtm_op_e'(dmi.op) == dm::DTM_READ)
              state_d = Read;
            else if (dm::dtm_op_e'(dmi.op) == dm::DTM_WRITE)
              state_d = Write;
          end
        end
        Read: begin
          dmi_req_valid = 1'b1;
          if (dmi_req_ready) state_d = WaitReadValid;
        end
        WaitReadValid: begin
          if (dmi_resp_valid) begin
            unique case (dmi_resp.resp)
              dm::DTM_SUCCESS: data_d = dmi_resp.data;
              dm::DTM_ERR:   begin data_d = 32'hDEAD_BEEF; error_dmi_op_failed = 1'b1; end
              dm::DTM_BUSY:  begin data_d = 32'hB051_B051; error_dmi_busy = 1'b1; end
              default:       data_d = 32'hBAAD_C0DE;
            endcase
            state_d = Idle;
          end
        end
        Write: begin
          dmi_req_valid = 1'b1;
          if (dmi_req_ready) state_d = WaitWriteValid;
        end
        WaitWriteValid: begin
          if (dmi_resp_valid) begin
            unique case (dmi_resp.resp)
              dm::DTM_ERR:  error_dmi_op_failed = 1'b1;
              dm::DTM_BUSY: error_dmi_busy = 1'b1;
              default: ;
            endcase
            state_d = Idle;
          end
        end
        default: begin
          if (dmi_resp_valid) state_d = Idle;
        end
      endcase

      if (update && state_q != Idle)          error_dmi_busy = 1'b1;
      if (capture && state_q inside {Read, WaitReadValid}) error_dmi_busy = 1'b1;
      if (error_dmi_busy && error_q == DMINoError)      error_d = DMIBusy;
      if (error_dmi_op_failed && error_q == DMINoError) error_d = DMIOPFailed;
      if (update && dtmcs_q.dmireset && dtmcs_select)   error_d = DMINoError;
    end
  end

  assign dmi_tdo = dr_q[0];

  always_comb begin : p_shift
    dr_d = dr_q;
    if (dmi_clear) begin
      dr_d = '0;
    end else begin
      if (capture && dmi_select) begin
        if (error_q == DMINoError && !error_dmi_busy)
          dr_d = {address_q, data_q, DMINoError};
        else if (error_q == DMIBusy || error_dmi_busy)
          dr_d = {address_q, data_q, DMIBusy};
      end
      if (shift && dmi_select)
        dr_d = {tdi, dr_q[$bits(dr_q)-1:1]};
    end
  end

  always_ff @(posedge tck or negedge trst_ni) begin
    if (!trst_ni) begin
      dr_q      <= '0;
      state_q   <= Idle;
      address_q <= '0;
      data_q    <= '0;
      error_q   <= DMINoError;
    end else begin
      dr_q      <= dr_d;
      state_q   <= state_d;
      address_q <= address_d;
      data_q    <= data_d;
      error_q   <= error_d;
    end
  end

  // ---------
  // TAP
  // ---------
  dmi_jtag_tap #(
    .IrLength    (5),
    .IdcodeValue (IdcodeValue)
  ) i_dmi_jtag_tap (
    .tck_i,
    .tms_i,
    .trst_ni,
    .td_i,
    .td_o,
    .tdo_oe_o,
    .testmode_i,
    .tck_o          ( tck            ),
    .dmi_clear_o    ( jtag_dmi_clear ),
    .update_o       ( update         ),
    .capture_o      ( capture        ),
    .shift_o        ( shift          ),
    .tdi_o          ( tdi            ),
    .dtmcs_select_o ( dtmcs_select   ),
    .dtmcs_tdo_i    ( dtmcs_q[0]     ),
    .dmi_select_o   ( dmi_select     ),
    .dmi_tdo_i      ( dmi_tdo        )
  );

  // ---------
  // No CDC (Single clock domain)
  // Direct wire assignments replacing dmi_cdc
  // ---------
  assign dmi_rst_no       = rst_ni;
  assign dmi_req_o        = dmi_req;
  assign dmi_req_valid_o  = dmi_req_valid;
  assign dmi_req_ready    = dmi_req_ready_i;
  assign dmi_resp         = dmi_resp_i;
  assign dmi_resp_valid   = dmi_resp_valid_i;
  assign dmi_resp_ready_o = dmi_resp_ready;



endmodule : dmi_jtag