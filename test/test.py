# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge

LATENCY = 2  # input register + output register


async def start(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.ena.value = 1
    dut.uio_in.value = 0
    dut.ui_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1


@cocotb.test()
async def test_reset(dut):
    """While rst_n = 0 both registers must be cleared."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.ena.value = 1
    dut.uio_in.value = 0
    dut.ui_in.value = 0xFF
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 3)
    await FallingEdge(dut.clk)
    assert int(dut.uo_out.value) == 0, "Output is not 0 during reset"


@cocotb.test()
async def test_multiplier_exhaustive(dut):
    """Check all 256 combinations, holding each input for LATENCY cycles."""
    await start(dut)
    for b in range(16):
        for a in range(16):
            dut.ui_in.value = (b << 4) | a   # A = ui_in[3:0], B = ui_in[7:4]
            await ClockCycles(dut.clk, LATENCY)
            await FallingEdge(dut.clk)
            p = int(dut.uo_out.value)
            assert p == a * b, f"{a} x {b}: expected {a * b}, got {p}"
    dut._log.info("All 256 combinations are correct")


@cocotb.test()
async def test_shift_through_registers(dut):
    """Apply a new input every cycle; each product must come out
    exactly LATENCY cycles later (data shifts through the registers)."""
    await start(dut)
    inputs = [(a, b) for b in range(16) for a in range(16)]
    for cycle in range(len(inputs) + LATENCY):
        await FallingEdge(dut.clk)
        if cycle >= LATENCY:
            a, b = inputs[cycle - LATENCY]
            p = int(dut.uo_out.value)
            assert p == a * b, f"cycle {cycle}: {a} x {b}: expected {a * b}, got {p}"
        if cycle < len(inputs):
            a, b = inputs[cycle]
            dut.ui_in.value = (b << 4) | a
    dut._log.info("Pipelined operation is correct (2-cycle latency)")
