import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


async def load_pin(dut, pin, extra_bits=0):
    nibbles = [(pin >> 12) & 0xF, (pin >> 8) & 0xF, (pin >> 4) & 0xF, pin & 0xF]
    for digit in nibbles:
        dut.ui_in.value = extra_bits | (1 << 4) | digit  # load_btn = 1
        await ClockCycles(dut.clk, 2)
        dut.ui_in.value = extra_bits | digit             # load_btn = 0
        await ClockCycles(dut.clk, 2)


async def submit_pin(dut, pin, extra_bits=0):
    await load_pin(dut, pin, extra_bits)
    dut.ui_in.value = extra_bits | (1 << 5)              # enter_lock_btn = 1
    await ClockCycles(dut.clk, 2)
    dut.ui_in.value = extra_bits                         # enter_lock_btn = 0
    await ClockCycles(dut.clk, 2)


async def read_4_digits(dut):
    # Sincroniza con el 1.er dígito (digit_sel = 4'b1000 = 0x8)
    for _ in range(8):
        if (int(dut.uio_out.value) & 0x0F) == 0x8:
            break
        await ClockCycles(dut.clk, 1)

    assert (int(dut.uio_out.value) & 0x0F) == 0x8
    d3 = int(dut.uo_out.value)
    status = (int(dut.uio_out.value) >> 4) & 0x0F

    await ClockCycles(dut.clk, 1)
    assert (int(dut.uio_out.value) & 0x0F) == 0x4
    d2 = int(dut.uo_out.value)

    await ClockCycles(dut.clk, 1)
    assert (int(dut.uio_out.value) & 0x0F) == 0x2
    d1 = int(dut.uo_out.value)

    await ClockCycles(dut.clk, 1)
    assert (int(dut.uio_out.value) & 0x0F) == 0x1
    d0 = int(dut.uo_out.value)

    return (d3, d2, d1, d0), status


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start 4-hex-digit Digital Safe test")

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

    assert int(dut.uio_oe.value) == 0xFF

    # Estado inicial: "0. 0 0 0", status = 0x3 (3 intentos)
    digits, status = await read_4_digits(dut)
    assert digits == (0xBF, 0x3F, 0x3F, 0x3F)
    assert status == 0x3

    # 1. Cargar PIN por defecto 0x1234 y verificar en displays ("1. 2 3 4")
    await load_pin(dut, 0x1234)
    digits, status = await read_4_digits(dut)
    assert digits == (0x86, 0x5B, 0x4F, 0x66)
    assert status == 0x3

    # Enviar Enter -> desbloquea ("0. P E n", unlocked=1, intentos=3 => status=0x7)
    dut.ui_in.value = 1 << 5
    await ClockCycles(dut.clk, 2)
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 2)

    digits, status = await read_4_digits(dut)
    assert digits == (0xBF, 0x73, 0x79, 0x54)
    assert status == 0x7

    # Verificar entrada de log vacía (entrada 3 -> "-. - - -", evt=00, unlocked=1 => status=0x4)
    dut.ui_in.value = (1 << 6) | 3
    await ClockCycles(dut.clk, 2)
    digits, status = await read_4_digits(dut)
    assert digits == (0xC0, 0x40, 0x40, 0x40)
    assert status == 0x4
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 2)

    # 2. Programar nueva contraseña personalizada: 0xA5C3 (prog_mode = ui_in[7])
    await submit_pin(dut, 0xA5C3, extra_bits=(1 << 7))
    digits, status = await read_4_digits(dut)
    assert digits == (0xF7, 0x6D, 0x39, 0x4F)  # "A. 5 C 3"
    assert status == 0x7

    # Salir de prog_mode y cerrar caja fuerte
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 2)
    dut.ui_in.value = 1 << 5
    await ClockCycles(dut.clk, 2)
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 2)

    digits, status = await read_4_digits(dut)
    assert digits == (0xBF, 0x3F, 0x3F, 0x3F)
    assert status == 0x3

    # 3. Probar contraseña vieja (0x1234) -> denegada (quedan 2 intentos => status=0x2)
    await submit_pin(dut, 0x1234)
    digits, status = await read_4_digits(dut)
    assert status == 0x2

    # 4. Probar nueva contraseña (0xA5C3) -> aceptada ("0. P E n", status=0x7)
    await submit_pin(dut, 0xA5C3)
    digits, status = await read_4_digits(dut)
    assert digits == (0xBF, 0x73, 0x79, 0x54)
    assert status == 0x7

    # Volver a cerrar
    dut.ui_in.value = 1 << 5
    await ClockCycles(dut.clk, 2)
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 2)

    # 5. Tres intentos fallidos consecutivos -> LOCKOUT ("L. o C d", alarm=1 => status=0x8)
    await submit_pin(dut, 0xDEAD)
    _, status = await read_4_digits(dut)
    assert status == 0x2

    await submit_pin(dut, 0xBEEF)
    _, status = await read_4_digits(dut)
    assert status == 0x1

    await submit_pin(dut, 0xCAFE)
    digits, status = await read_4_digits(dut)
    assert digits == (0xB8, 0x5C, 0x39, 0x5E)  # "L. o C d"
    assert status == 0x8

    # 6. Verificar los 4 registros del historial circular (log_mode = ui_in[6])
    # Entrada 0: 0xBEEF (DENIED=10, alarm=1 => status=0xA)
    dut.ui_in.value = (1 << 6) | 0
    await ClockCycles(dut.clk, 2)
    digits, status = await read_4_digits(dut)
    assert digits == (0xFC, 0x79, 0x79, 0x71)  # "b. E E F"
    assert status == 0xA

    # Entrada 1: 0xCAFE (LOCKOUT=11, alarm=1 => status=0xB)
    dut.ui_in.value = (1 << 6) | 1
    await ClockCycles(dut.clk, 2)
    digits, status = await read_4_digits(dut)
    assert digits == (0xB9, 0x77, 0x71, 0x79)  # "C. A F E"
    assert status == 0xB

    # Entrada 2: 0xA5C3 (GRANTED=01, alarm=1 => status=0x9)
    dut.ui_in.value = (1 << 6) | 2
    await ClockCycles(dut.clk, 2)
    digits, status = await read_4_digits(dut)
    assert digits == (0xF7, 0x6D, 0x39, 0x4F)  # "A. 5 C 3"
    assert status == 0x9

    # Entrada 3: 0xDEAD (DENIED=10, alarm=1 => status=0xA)
    dut.ui_in.value = (1 << 6) | 3
    await ClockCycles(dut.clk, 2)
    digits, status = await read_4_digits(dut)
    assert digits == (0xDE, 0x79, 0x77, 0x5E)  # "d. E A d"
    assert status == 0xA
