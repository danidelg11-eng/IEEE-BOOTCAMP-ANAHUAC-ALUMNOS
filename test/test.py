# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

# 7-segment patterns {g, f, e, d, c, b, a} (common cathode, without dp)
SEG_MAP = {
    0: 0b0111111,
    1: 0b0000110,
    2: 0b1011011,
    3: 0b1001111,
    4: 0b1100110,
    5: 0b1101101,
    6: 0b1111101,
    7: 0b0000111,
    8: 0b1111111,
    9: 0b1101111,
    "A": 0b1110111,
    "L": 0b0111000,
}


def pack_ui(
    view_mode=0, edit_en=0, field_sel=0, inc_btn=0, alarm_en=0, fast_sim=1
):
    return (
        (view_mode & 0x3)
        | ((edit_en & 0x1) << 2)
        | ((field_sel & 0x3) << 3)
        | ((inc_btn & 0x1) << 5)
        | ((alarm_en & 0x1) << 6)
        | ((fast_sim & 0x1) << 7)
    )


async def read_digits(dut):
    """Captures one full 6-digit mux sweep (4 clock cycles per digit when fast_sim=1)."""
    digits = [None] * 6
    for _ in range(24):
        await ClockCycles(dut.clk, 1)
        uio = int(dut.uio_out.value)
        uo = int(dut.uo_out.value) & 0x7F
        sel = uio & 0x3F
        for i in range(6):
            if sel == (1 << i):
                digits[i] = uo
    # Return left-to-right: [d5, d4, d3, d2, d1, d0]
    return [digits[5], digits[4], digits[3], digits[2], digits[1], digits[0]]


async def pulse_inc(dut, view_mode, field_sel, times=1, alarm_en=0):
    for _ in range(times):
        dut.ui_in.value = pack_ui(
            view_mode=view_mode,
            edit_en=1,
            field_sel=field_sel,
            inc_btn=1,
            alarm_en=alarm_en,
            fast_sim=1,
        )
        await ClockCycles(dut.clk, 2)
        dut.ui_in.value = pack_ui(
            view_mode=view_mode,
            edit_en=1,
            field_sel=field_sel,
            inc_btn=0,
            alarm_en=alarm_en,
            fast_sim=1,
        )
        await ClockCycles(dut.clk, 2)


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = pack_ui(fast_sim=1)
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # 1. Verify initial Time (00.00.00) right after reset
    dut.ui_in.value = pack_ui(view_mode=0, edit_en=1, fast_sim=1)
    await ClockCycles(dut.clk, 1)
    time_digits = await read_digits(dut)
    assert time_digits == [SEG_MAP[0]] * 6, f"Expected 00.00.00, got {time_digits}"

    # 2. Verify initial Date (01.01.26) and non-leap status (is_leap == 0)
    dut.ui_in.value = pack_ui(view_mode=1, edit_en=1, fast_sim=1)
    await ClockCycles(dut.clk, 1)
    date_digits = await read_digits(dut)
    assert date_digits == [
        SEG_MAP[0],
        SEG_MAP[1],
        SEG_MAP[0],
        SEG_MAP[1],
        SEG_MAP[2],
        SEG_MAP[6],
    ], f"Expected 01.01.26, got {date_digits}"
    assert ((int(dut.uio_out.value) >> 7) & 1) == 0

    # 3. Verify default Alarm (AL 07.00)
    dut.ui_in.value = pack_ui(view_mode=2, edit_en=1, fast_sim=1)
    await ClockCycles(dut.clk, 1)
    alarm_digits = await read_digits(dut)
    assert alarm_digits == [
        SEG_MAP["A"],
        SEG_MAP["L"],
        SEG_MAP[0],
        SEG_MAP[7],
        SEG_MAP[0],
        SEG_MAP[0],
    ], f"Expected AL 07.00, got {alarm_digits}"

    # 4. Set Date to 28.02.28 (leap year 2028) and verify is_leap == 1
    await pulse_inc(dut, view_mode=1, field_sel=2, times=2)   # Year: 26 -> 28
    await pulse_inc(dut, view_mode=1, field_sel=1, times=1)   # Month: 01 -> 02
    await pulse_inc(dut, view_mode=1, field_sel=0, times=27)  # Day: 01 -> 28
    assert ((int(dut.uio_out.value) >> 7) & 1) == 1

    # 5. Set Alarm to 00:00 and Time to 23:59:00, then run 60 simulated seconds
    await pulse_inc(dut, view_mode=2, field_sel=0, times=17, alarm_en=1)  # Alarm hr: 07 -> 00
    await pulse_inc(dut, view_mode=0, field_sel=0, times=23, alarm_en=1)  # Time hr: 00 -> 23
    await pulse_inc(dut, view_mode=0, field_sel=1, times=59, alarm_en=1)  # Time min: 00 -> 59

    # Run clock with fast_sim=1 (16 cycles per second -> 60s = 960 cycles)
    dut.ui_in.value = pack_ui(view_mode=1, edit_en=0, alarm_en=1, fast_sim=1)
    await ClockCycles(dut.clk, 60 * 16 + 4)

    # Verify alarm triggered (uio_out[6] == 1) and date rolled into leap day 29.02.28
    assert ((int(dut.uio_out.value) >> 6) & 1) == 1
    leap_digits = await read_digits(dut)
    assert leap_digits == [
        SEG_MAP[2],
        SEG_MAP[9],
        SEG_MAP[0],
        SEG_MAP[2],
        SEG_MAP[2],
        SEG_MAP[8],
    ], f"Expected 29.02.28, got {leap_digits}"

    dut._log.info("All tests passed!")
