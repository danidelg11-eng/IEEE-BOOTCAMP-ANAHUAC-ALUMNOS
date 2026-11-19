# SPDX-FileCopyrightText: © 2026 Your Name
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer


async def start_and_reset(dut):
    """Start a 100 kHz clock and apply a reset."""
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


async def multiply(dut, a, b):
    """Apply A and B, wait exactly one rising edge, return uo_out."""
    await FallingEdge(dut.clk)
    dut.ui_in.value = (a << 4) | b      # A = ui_in[7:4], B = ui_in[3:0]
    await RisingEdge(dut.clk)           # the product is registered here
    await FallingEdge(dut.clk)
    return int(dut.uo_out.value)


@cocotb.test()
async def test_reset(dut):
    """After reset the product register is 0 and the unused pins are 0."""
    dut._log.info("Reset test")
    await start_and_reset(dut)

    assert int(dut.uo_out.value) == 0
    assert int(dut.uio_out.value) == 0
    assert int(dut.uio_oe.value) == 0


@cocotb.test()
async def test_known_values(dut):
    """Spot checks, including the corner cases 0x0, 1x15, 8x8 and 15x15."""
    dut._log.info("Known values test")
    await start_and_reset(dut)

    for a, b, expected in [(0, 0, 0), (1, 15, 15), (15, 1, 15), (8, 8, 64),
                           (5, 3, 15), (7, 9, 63), (13, 11, 143), (15, 15, 225)]:
        got = await multiply(dut, a, b)
        assert got == expected, f"{a} x {b}: expected {expected}, got {got}"


@cocotb.test()
async def test_exhaustive(dut):
    """All 256 combinations of A and B against the reference model a * b."""
    dut._log.info("Exhaustive test: 256 combinations")
    await start_and_reset(dut)

    errors = 0
    for a in range(16):
        for b in range(16):
            got = await multiply(dut, a, b)
            if got != a * b:
                errors += 1
                dut._log.error(f"{a} x {b}: expected {a * b}, got {got}")
    assert errors == 0, f"{errors} wrong products out of 256"


@cocotb.test()
async def test_async_reset_mid_operation(dut):
    """Asserting rst_n clears the product immediately (no clock edge needed)."""
    dut._log.info("Asynchronous reset test")
    await start_and_reset(dut)

    got = await multiply(dut, 15, 15)
    assert got == 225

    await Timer(1, unit="us")           # mid-cycle, away from a clock edge
    dut.rst_n.value = 0
    await Timer(1, unit="us")
    assert int(dut.uo_out.value) == 0, "reset did not clear the product"

    dut.rst_n.value = 1
    got = await multiply(dut, 9, 7)     # works again after reset
    assert got == 63

