#!/usr/bin/env python3
"""
JTAG host-side driver for the FFN ASIC/FPGA debug interface.

Hardware required:
  - FTDI FT232H (or FT2232H) breakout board, connected to Pmod JA header:
      FT232H  D0 → Pmod JA[1] (TCK)
      FT232H  D1 → Pmod JA[3] (TDI)   -- FTDI out, FPGA in
      FT232H  D2 ← Pmod JA[4] (TDO)   -- FPGA out, FTDI in
      FT232H  D3 → Pmod JA[2] (TMS)
      FT232H  D4 → Pmod JA[7] (TRST_N)
  - Also connect GND between the FT232H and the Pmod GND pins.

Software:  pip install pyftdi

Usage:
  python jtag_host.py              # read all debug registers once
  python jtag_host.py --monitor    # poll in a loop
  python jtag_host.py --force-start  # pulse JTAG force-start
"""

import argparse
import struct
import sys
import time
from contextlib import contextmanager

try:
    from pyftdi.gpio import GpioAsyncController
except ImportError:
    print("ERROR: pyftdi not installed.  Run:  pip install pyftdi")
    sys.exit(1)


# ---------------------------------------------------------------------------
# FT232H GPIO pin mapping (directly on the low-byte port, AD0..AD7)
# ---------------------------------------------------------------------------
PIN_TCK   = 0x01   # AD0
PIN_TDI   = 0x02   # AD1
PIN_TDO   = 0x04   # AD2  (input)
PIN_TMS   = 0x08   # AD3
PIN_TRST  = 0x10   # AD4

OUTPUT_MASK = PIN_TCK | PIN_TDI | PIN_TMS | PIN_TRST   # 0x1B — TDO is input

# ---------------------------------------------------------------------------
# JTAG IR instruction encodings (must match jtag_debug_regs.sv)
# ---------------------------------------------------------------------------
IR_WIDTH     = 4
IR_BYPASS    = 0b1111
IR_IDCODE    = 0b0001
IR_STATUS    = 0b0010   # 16 bits
IR_FFN_IN    = 0b0011   # 224 bits  (N=2)
IR_FFN_PIPE  = 0b0100   # 128 bits  (N=2)
IR_CONTROL   = 0b0101   # 2 bits

N = 2
STATUS_W   = 16
FFN_IN_W   = (N*N + N*N + N + N + N) * 16   # 224
FFN_PIPE_W = N * 16 * 4                      # 128
CONTROL_W  = 2
IDCODE_W   = 32


class JtagGpio:
    """Bit-bang JTAG over an FT232H GPIO port."""

    def __init__(self, url: str = "ftdi://ftdi:232h/1"):
        self._gpio = GpioAsyncController()
        self._gpio.configure(url, direction=OUTPUT_MASK)
        self._out = PIN_TRST   # TRST_N high (inactive), everything else low
        self._flush()

    def close(self):
        self._gpio.close()

    # --- low-level ---

    def _flush(self):
        self._gpio.write(self._out)

    def _set(self, mask: int, val: bool):
        if val:
            self._out |= mask
        else:
            self._out &= ~mask
        self._flush()

    def _get_tdo(self) -> int:
        pins = self._gpio.read()
        return 1 if (pins & PIN_TDO) else 0

    def _tck_pulse(self) -> int:
        """Drive TCK low→high→low, sample TDO on falling edge."""
        self._out &= ~PIN_TCK
        self._flush()
        self._out |= PIN_TCK
        self._flush()
        tdo = self._get_tdo()
        self._out &= ~PIN_TCK
        self._flush()
        return tdo

    # --- JTAG protocol ---

    def reset(self):
        """Assert TRST_N low, then release."""
        self._set(PIN_TRST, False)
        time.sleep(0.001)
        self._set(PIN_TRST, True)
        time.sleep(0.001)
        # Also drive TMS=1 for 5 clocks to reach TLR via state machine
        self._set(PIN_TMS, True)
        for _ in range(5):
            self._tck_pulse()
        # Go to RTI
        self._set(PIN_TMS, False)
        self._tck_pulse()

    def shift_ir(self, ir_val: int, ir_width: int = IR_WIDTH):
        """Navigate to Shift-IR, clock in ir_val (LSB first), return to RTI."""
        # RTI → Select-DR → Select-IR → Capture-IR → Shift-IR
        self._set(PIN_TMS, True);  self._tck_pulse()   # → Select-DR
        self._set(PIN_TMS, True);  self._tck_pulse()   # → Select-IR
        self._set(PIN_TMS, False); self._tck_pulse()    # → Capture-IR
        self._set(PIN_TMS, False); self._tck_pulse()    # → Shift-IR

        for i in range(ir_width):
            bit = (ir_val >> i) & 1
            self._set(PIN_TDI, bool(bit))
            if i == ir_width - 1:
                self._set(PIN_TMS, True)    # exit on last bit
            self._tck_pulse()

        # Exit1-IR → Update-IR → RTI
        self._set(PIN_TMS, True);  self._tck_pulse()    # → Update-IR
        self._set(PIN_TMS, False); self._tck_pulse()    # → RTI

    def shift_dr(self, tdi_val: int, width: int) -> int:
        """Navigate to Shift-DR, clock width bits, return captured TDO data."""
        # RTI → Select-DR → Capture-DR → Shift-DR
        self._set(PIN_TMS, True);  self._tck_pulse()    # → Select-DR
        self._set(PIN_TMS, False); self._tck_pulse()    # → Capture-DR
        self._set(PIN_TMS, False); self._tck_pulse()    # → Shift-DR

        tdo_val = 0
        for i in range(width):
            bit = (tdi_val >> i) & 1
            self._set(PIN_TDI, bool(bit))
            if i == width - 1:
                self._set(PIN_TMS, True)    # exit on last bit
            tdo = self._tck_pulse()
            tdo_val |= (tdo << i)

        # Exit1-DR → Update-DR → RTI
        self._set(PIN_TMS, True);  self._tck_pulse()    # → Update-DR
        self._set(PIN_TMS, False); self._tck_pulse()    # → RTI

        return tdo_val


# ---------------------------------------------------------------------------
# High-level register access
# ---------------------------------------------------------------------------

def read_idcode(jtag: JtagGpio) -> int:
    jtag.shift_ir(IR_IDCODE)
    return jtag.shift_dr(0, IDCODE_W)


def read_status(jtag: JtagGpio) -> dict:
    jtag.shift_ir(IR_STATUS)
    raw = jtag.shift_dr(0, STATUS_W)
    return {
        "raw":           f"0x{raw:04X}",
        "ready":         bool(raw & (1 << 0)),
        "done":          bool(raw & (1 << 1)),
        "ffn_start":     bool(raw & (1 << 2)),
        "rx_dv":         bool(raw & (1 << 3)),
        "tx_dv":         bool(raw & (1 << 4)),
        "tx_busy":       bool(raw & (1 << 5)),
        "wrapper_state": (raw >> 6) & 0x7,
    }


def _extract_bf16_array(packed: int, offset_words: int, count: int) -> list[str]:
    """Pull `count` bf16 words starting at word-offset from a packed integer."""
    results = []
    for i in range(count):
        word = (packed >> ((offset_words + i) * 16)) & 0xFFFF
        fp32_bits = word << 16
        fp32 = struct.unpack(">f", struct.pack(">I", fp32_bits))[0]
        results.append(f"0x{word:04X} ({fp32:.4g})")
    return results


def read_ffn_in(jtag: JtagGpio) -> dict:
    jtag.shift_ir(IR_FFN_IN)
    raw = jtag.shift_dr(0, FFN_IN_W)
    off = 0
    w1 = _extract_bf16_array(raw, off, N*N); off += N*N
    w2 = _extract_bf16_array(raw, off, N*N); off += N*N
    x  = _extract_bf16_array(raw, off, N);   off += N
    b1 = _extract_bf16_array(raw, off, N);   off += N
    b2 = _extract_bf16_array(raw, off, N)
    return {"W1": w1, "W2": w2, "x": x, "b1": b1, "b2": b2}


def read_ffn_pipe(jtag: JtagGpio) -> dict:
    jtag.shift_ir(IR_FFN_PIPE)
    raw = jtag.shift_dr(0, FFN_PIPE_W)
    off = 0
    mac_out   = _extract_bf16_array(raw, off, N); off += N
    gelu_out  = _extract_bf16_array(raw, off, N); off += N
    mac_out_2 = _extract_bf16_array(raw, off, N); off += N
    y         = _extract_bf16_array(raw, off, N)
    return {"mac_out": mac_out, "gelu_out": gelu_out, "mac_out_2": mac_out_2, "y": y}


def write_control(jtag: JtagGpio, force_start: bool = False, force_rst: bool = False):
    val = (int(force_rst) << 1) | int(force_start)
    jtag.shift_ir(IR_CONTROL)
    jtag.shift_dr(val, CONTROL_W)


# ---------------------------------------------------------------------------
# Pretty-print helpers
# ---------------------------------------------------------------------------

def print_section(title: str):
    print(f"\n{'='*50}")
    print(f"  {title}")
    print(f"{'='*50}")


def dump_all(jtag: JtagGpio):
    idcode = read_idcode(jtag)
    print_section("IDCODE")
    expected = 0x1FF00001
    match = "OK" if idcode == expected else "MISMATCH"
    print(f"  IDCODE = 0x{idcode:08X}  (expect 0x{expected:08X})  [{match}]")

    status = read_status(jtag)
    print_section("STATUS  (DBG_STATUS, 16 bits)")
    for k, v in status.items():
        print(f"  {k:20s} = {v}")

    ffn_in = read_ffn_in(jtag)
    print_section("FFN INPUTS  (DBG_FFN_IN, 224 bits)")
    for name, vals in ffn_in.items():
        print(f"  {name}:")
        for i, v in enumerate(vals):
            print(f"    [{i}] {v}")

    ffn_pipe = read_ffn_pipe(jtag)
    print_section("FFN PIPELINE  (DBG_FFN_PIPE, 128 bits)")
    for name, vals in ffn_pipe.items():
        print(f"  {name}:")
        for i, v in enumerate(vals):
            print(f"    [{i}] {v}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="JTAG debug host for FFN FPGA")
    parser.add_argument("--url", default="ftdi://ftdi:232h/1",
                        help="pyftdi device URL  (default: ftdi://ftdi:232h/1)")
    parser.add_argument("--monitor", action="store_true",
                        help="Continuously poll registers every 2 seconds")
    parser.add_argument("--force-start", action="store_true",
                        help="Pulse JTAG force-start then read back")
    parser.add_argument("--force-reset", action="store_true",
                        help="Assert JTAG force-reset, wait 10 ms, then release")
    args = parser.parse_args()

    jtag = JtagGpio(url=args.url)
    jtag.reset()

    if args.force_reset:
        print("Asserting JTAG force-reset...")
        write_control(jtag, force_rst=True)
        time.sleep(0.01)
        write_control(jtag, force_rst=False)
        print("Released.")

    if args.force_start:
        print("Pulsing JTAG force-start...")
        write_control(jtag, force_start=True)
        time.sleep(0.001)
        write_control(jtag, force_start=False)
        print("Done.\n")

    if args.monitor:
        try:
            while True:
                print(f"\n--- JTAG snapshot @ {time.strftime('%H:%M:%S')} ---")
                dump_all(jtag)
                time.sleep(2.0)
        except KeyboardInterrupt:
            print("\nStopped.")
    else:
        dump_all(jtag)

    jtag.close()


if __name__ == "__main__":
    main()
