`timescale 1ns/1ps

`include "uvm_macros.svh"
`include "uvm_pkg.sv"
`include "ffn_if.sv"
`include "ffn_pkg.sv"
`include "ffn_ref_rtl.sv"

module ffn_uvm_tb;

    localparam int N = 2;

    logic clk;
    logic done_dut;  // FFN completion pulse (not used by UVM scoreboard)

    ffn_if #(.N(N)) ffn_vif(.clk(clk));

    top #(.N(N)) dut (
        .clk           (clk),
        .rst_n         (ffn_vif.rst_n),
        .start         (1'b1),
        .w1            (ffn_vif.w1),
        .w2            (ffn_vif.w2),
        .b1            (ffn_vif.b1),
        .b2            (ffn_vif.b2),
        .x             (ffn_vif.x),
        .y             (ffn_vif.y),
        .done          (done_dut),
        .dbg_mac_out   (),
        .dbg_gelu_out  (),
        .dbg_mac_out_2 ()
    );

    // Combinational RTL-accurate reference for exact scoreboard comparisons.
    ffn_ref_rtl #(.N(N)) ref_rtl (
        .w2    (ffn_vif.w2),
        .w1    (ffn_vif.w1),
        .b1    (ffn_vif.b1),
        .b2    (ffn_vif.b2),
        .x     (ffn_vif.x),
        .y_ref (ffn_vif.y_ref)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        ffn_vif.rst_n = 0;
        repeat (5) @(posedge clk);
        ffn_vif.rst_n = 1;
    end

    initial begin
        import ffn_pkg::*;
        uvm_pkg::uvm_config_db#(virtual ffn_if#(N))::set(null, "uvm_test_top.env.agt*", "vif", ffn_vif);
        uvm_pkg::run_test("ffn_test");
    end

endmodule
