# UVM Testbench for FFN Top-Level Design

Tests the feedforward network pipeline: MAC1 → GELU → MAC2.

## Requirements

- UVM 1.2 (set `UVM_HOME` or `QUESTA_HOME`)
- Supported simulators: Questa/ModelSim, VCS, Xcelium

## Structure

| File | Description |
|------|-------------|
| `ffn_if.sv` | Virtual interface with clocking block |
| `ffn_transaction.sv` | UVM sequence item (w1, w2, b1, b2, x, y_exp, y_act) |
| `ffn_sequence.sv` | Random stimulus sequence |
| `ffn_driver.sv` | Drives DUT inputs, waits for pipeline latency |
| `ffn_monitor.sv` | Captures DUT outputs on change |
| `ffn_agent.sv` | Active agent (driver + sequencer + monitor) |
| `ffn_ref_model.sv` | SW model (MAC + GELU approximation) |
| `ffn_scoreboard.sv` | Compares expected vs actual (tolerance for GELU) |
| `ffn_env.sv` | UVM environment |
| `ffn_test.sv` | Default test |
| `ffn_pkg.sv` | Package aggregating components |
| `ffn_uvm_tb.sv` | Top-level testbench module |

## Running (Questa)

```bash
export UVM_HOME=/path/to/uvm-1.2   # or use QUESTA_HOME/verilog_src/uvm-1.2
make questa
```

For GUI:

```bash
make questa_gui
```

## Note

The reference model uses a GELU approximation (sigmoid-based); the RTL uses a PWL LUT. The scoreboard allows a small tolerance (default 2 LSB) for minor differences.
