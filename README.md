![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)
4-bit Array Multiplier — IEEE Open Silicon Bootcamp 2026
Gate-level 4×4 array multiplier (16 AND gates + 12 full adders) with D flip-flop
input and output registers, designed for Tiny Tapeout.
Project documentation
Signal	Function
`ui_in[3:0]`	A (multiplicand)
`ui_in[7:4]`	B (multiplier)
`uo_out[7:0]`	P = A × B (2 clock cycles later)
`clk`	Register clock
`rst_n`	Reset, active low
Authors
Daniel Delgado Gutiérrez
David Suárez Pérez
Emiliano Almanza Repetto
Inés Tejada Madrazo
María Pía Pacheco Rodríguez
Repository layout
```
src/project.v         Top module tt_um_danidelg11_eng_multiplier_4bit
src/register_8.v      8-bit register (8 D flip-flops)
src/d_ff.v            D flip-flop with asynchronous active-low reset
src/ripple_carry_4.v  4-bit ripple-carry adder (one row of the array)
src/full_adder.v      1-bit full adder
test/test.py          cocotb tests: reset, all 256 combinations, pipelined operation
test/tb.v             Testbench wrapper
docs/info.md          Datasheet
info.yaml             Tiny Tapeout project configuration
```
Running the tests
```bash
cd test
make
```
Resources
Tiny Tapeout FAQ
Digital design lessons
