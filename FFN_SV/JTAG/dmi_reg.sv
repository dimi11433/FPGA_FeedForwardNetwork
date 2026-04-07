// dmi_reg.sv
// Maps DMI addresses to internal signals from top.sv
// Address map (7-bit):
//   0x00 = mac_out[0][0]    0x01 = mac_out[0][1]
//   0x02 = mac_out[1][0]    0x03 = mac_out[1][1]
//   0x04 = gelu_out[0][0]   0x05 = gelu_out[0][1]
//   0x06 = gelu_out[1][0]   0x07 = gelu_out[1][1]
//   0x08 = mac_out_2[0][0]  0x09 = mac_out_2[0][1]
//   0x0A = mac_out_2[1][0]  0x0B = mac_out_2[1][1]
//   0x0C = y[0][0]          0x0D = y[0][1]
//   0x0E = y[1][0]          0x0F = y[1][1]
//   0x10 = ready_reg1 (packed 4 bits)
//   0x11 = ready_reg2 (packed 4 bits)
//   0x20 = dtmcs_status (full 32-bit status word)

module dmi_reg #(parameter N = 2) (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [6:0]  dmi_addr,
    input  logic [31:0] dmi_wdata,
    input  logic [1:0]  dmi_op,
    input  logic        dmi_req_valid,
    output logic        dmi_req_ready,
    output logic [31:0] dmi_rdata,
    output logic [1:0]  dmi_resp,
    output logic        dmi_resp_valid,
    input  logic        dmi_resp_ready,
    input  logic [15:0] mac_out   [0:N-1][0:N-1],
    input  logic [15:0] gelu_out  [0:N-1][0:N-1],
    input  logic [15:0] mac_out_2 [0:N-1][0:N-1],
    input  logic [15:0] y         [0:N-1][0:N-1],
    input  logic        ready1    [0:N-1][0:N-1],
    input  logic        ready2    [0:N-1][0:N-1],
    input  logic [31:0] dtmcs_status
);

    logic [31:0] rdata_reg;
    logic        resp_valid_reg;
    logic [1:0]  resp_reg;

    assign dmi_req_ready  = 1'b1;
    assign dmi_rdata      = rdata_reg;
    assign dmi_resp_valid = resp_valid_reg;
    assign dmi_resp       = resp_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata_reg      <= 32'h0;
            resp_valid_reg <= 1'b0;
            resp_reg       <= 2'h0;
        end else begin
            // Do not auto-clear resp_valid — hold it high until next request.
            // With VIO-driven TCK (slow), the TCK-domain FSM in WaitReadValid
            // would miss a 1-cycle pulse. Holding it high lets the FSM sample
            // it on the next TCK posedge regardless of timing.
            if (dmi_req_valid) begin
                resp_valid_reg <= 1'b1;
                resp_reg       <= 2'h0;
                case (dmi_addr)
                    7'h00: rdata_reg <= {16'h0, mac_out[0][0]};
                    7'h01: rdata_reg <= {16'h0, mac_out[0][1]};
                    7'h02: rdata_reg <= {16'h0, mac_out[1][0]};
                    7'h03: rdata_reg <= {16'h0, mac_out[1][1]};
                    7'h04: rdata_reg <= {16'h0, gelu_out[0][0]};
                    7'h05: rdata_reg <= {16'h0, gelu_out[0][1]};
                    7'h06: rdata_reg <= {16'h0, gelu_out[1][0]};
                    7'h07: rdata_reg <= {16'h0, gelu_out[1][1]};
                    7'h08: rdata_reg <= {16'h0, mac_out_2[0][0]};
                    7'h09: rdata_reg <= {16'h0, mac_out_2[0][1]};
                    7'h0A: rdata_reg <= {16'h0, mac_out_2[1][0]};
                    7'h0B: rdata_reg <= {16'h0, mac_out_2[1][1]};
                    7'h0C: rdata_reg <= {16'h0, y[0][0]};
                    7'h0D: rdata_reg <= {16'h0, y[0][1]};
                    7'h0E: rdata_reg <= {16'h0, y[1][0]};
                    7'h0F: rdata_reg <= {16'h0, y[1][1]};
                    7'h10: rdata_reg <= {28'h0,
                                         ready1[1][1], ready1[1][0],
                                         ready1[0][1], ready1[0][0]};
                    7'h11: rdata_reg <= {28'h0,
                                         ready2[1][1], ready2[1][0],
                                         ready2[0][1], ready2[0][0]};
                    7'h20: rdata_reg <= dtmcs_status;
                    default: begin
                        rdata_reg <= 32'hDEAD_BEEF;
                        resp_reg  <= 2'h2;
                    end
                endcase
            end
        end
    end

endmodule