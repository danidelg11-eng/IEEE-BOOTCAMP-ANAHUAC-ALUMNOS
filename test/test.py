# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


def pack_ui(a: int, b: int) -> int:
    """Empaqueta A en ui_in[7:4] y B en ui_in[3:0]."""
    return ((a & 0xF) << 4) | (b & 0xF)


async def multiply_hw(dut, a: int, b: int) -> int:
    """Ejecuta una multiplicación en el módulo Verilog (1 ciclo LOAD + 4 ciclos shift)."""
    # 1. Cargar operandos y activar LOAD = 1 (uio_in[0])
    dut.ui_in.value = pack_ui(a, b)
    dut.uio_in.value = 0x01
    await ClockCycles(dut.clk, 1)

    # 2. Desactivar LOAD = 0 y esperar los 4 desplazamientos + 1 ciclo de estabilización
    dut.uio_in.value = 0x00
    await ClockCycles(dut.clk, 5)

    return int(dut.uo_out.value)


@cocotb.test()
async def test_project(dut):
    dut._log.info("Iniciando pruebas del multiplicador secuencial de 4 bits")

    # Reloj de 10 us (100 kHz). Nota: si usas cocotb < 2.0, cambia 'unit' por 'units'
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset activo en bajo
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)

    # Verificar estado tras reset
    assert int(dut.uo_out.value) == 0, f"Se esperaba 0 tras reset, se obtuvo {int(dut.uo_out.value)}"

    # Barrido completo de las 256 combinaciones (0..15 x 0..15)
    for a in range(16):
        for b in range(16):
            resultado = await multiply_hw(dut, a, b)
            esperado = a * b
            assert resultado == esperado, (
                f"Error en {a} * {b}: esperado {esperado} ({esperado:08b}), "
                f"obtenido {resultado} ({resultado:08b})"
            )

    dut._log.info("¡Todas las 256 combinaciones pasaron correctamente!")nes pasaron correctamente.")
