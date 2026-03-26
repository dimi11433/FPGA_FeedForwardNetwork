`ifndef FFN_PKG_SV
`define FFN_PKG_SV

`include "uvm_pkg.sv"

package ffn_pkg;
    import uvm_pkg::*;

    `include "ffn_transaction.sv"
    `include "ffn_sequence.sv"
    `include "ffn_driver.sv"
    `include "ffn_monitor.sv"
    `include "ffn_agent.sv"
    `include "ffn_ref_model.sv"
    `include "ffn_scoreboard.sv"
    `include "ffn_env.sv"
    `include "ffn_test.sv"
endpackage

`endif
