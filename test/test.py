import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


async def submit_code(dut, code):
    dut.ui_in.value = (1 << 4) | (code & 0xF)  # enter_btn = 1, key_in = code
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = code & 0xF               # enter_btn = 0
    await ClockCycles(dut.clk, 1)


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start 4-bit Hex Digital Safe test")

    # Nota: si tu plantilla anterior usaba units="us", cambia unit por units
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    # Estado inicial: Display 1 = '0' (0x3F), Display 2 = '3' intentos (0x4F)
    assert int(dut.uio_oe.value) == 0xFF
    assert int(dut.uo_out.value) == 0x3F
    assert int(dut.uio_out.value) == 0x4F

    # 1. Intento fallido con 0x5 -> Display 1 = '5' (0x6D), Display 2 = '2' (0x5B)
    await submit_code(dut, 0x5)
    assert int(dut.uo_out.value) == 0x6D
    assert int(dut.uio_out.value) == 0x5B

    # 2. Intento correcto con 0xA -> Display 1 = 'U' + dp (0xBE), Display 2 = '3' (0x4F)
    await submit_code(dut, 0xA)
    assert int(dut.uo_out.value) == 0xBE
    assert int(dut.uio_out.value) == 0x4F

    # 3. Cerrar caja fuerte (lock_btn = ui_in[5])
    dut.ui_in.value = 1 << 5
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 1)
    assert int(dut.uo_out.value) == 0x3F  # '0'
    assert int(dut.uio_out.value) == 0x4F # '3'

    # 4. Tres intentos fallidos consecutivos -> LOCKOUT
    await submit_code(dut, 0x1)  # quedan 2
    assert int(dut.uio_out.value) == 0x5B
    await submit_code(dut, 0x2)  # queda 1
    assert int(dut.uio_out.value) == 0x06
    await submit_code(dut, 0xF)  # quedan 0 -> LOCKOUT

    # Display 1 = 'L' (0x38), Display 2 = '0' + dp alarma (0xBF)
    assert int(dut.uo_out.value) == 0x38
    assert int(dut.uio_out.value) == 0xBF

    # Confirmar que bloqueada rechaza incluso el código correcto
    await submit_code(dut, 0xA)
    assert int(dut.uo_out.value) == 0x38
    assert int(dut.uio_out.value) == 0xBF

    # 5. Consultar registro de accesos (log_mode = 1 en ui_in[6])
    # Entrada 0: código 5 (0xED con dp=1) | resultado 'd' Denied (0xDE con dp=1)
    dut.ui_in.value = (1 << 6) | 0
    await ClockCycles(dut.clk, 1)
    assert int(dut.uo_out.value) == 0xED
    assert int(dut.uio_out.value) == 0xDE

    # Entrada 1: código A (0xF7 con dp=1) | resultado 'A' Granted (0xF7 con dp=1)
    dut.ui_in.value = (1 << 6) | 1
    await ClockCycles(dut.clk, 1)
    assert int(dut.uo_out.value) == 0xF7
    assert int(dut.uio_out.value) == 0xF7

    # Entrada 4: código F (0xF1 con dp=1) | resultado 'E' Lockout (0xF9 con dp=1)
    dut.ui_in.value = (1 << 6) | 4
    await ClockCycles(dut.clk, 1)
    assert int(dut.uo_out.value) == 0xF1
    assert int(dut.uio_out.value) == 0xF9

    # Entrada 5 (vacía): Display 1 = '-' + dp (0xC0) | Display 2 = '-' (0x40)
    dut.ui_in.value = (1 << 6) | 5
    await ClockCycles(dut.clk, 1)
    assert int(dut.uo_out.value) == 0xC0
    assert int(dut.uio_out.value) == 0x40
