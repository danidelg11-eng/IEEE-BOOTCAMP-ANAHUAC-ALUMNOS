<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project multiplies two 4-bit unsigned numbers and outputs the 8-bit product,
using a gate-level **array multiplier** with D flip-flop registers at the input and output.

- **A** = `ui_in[3:0]` (multiplicand), **B** = `ui_in[7:4]` (multiplier)
- **P** = `uo_out[7:0]` = A × B (0 to 225)

### Datapath

1. **16 AND gates** generate the partial products `a[i] AND b[j]`.
2. **3 4-bit ripple-carry adders** (`u_row1`, `u_row2`, `u_row3`), each made of
   4 full adders, add the partial products row by row (12 full adders in total).
   - Row 1 adds `{0, a3b0, a2b0, a1b0}` + `{a3b1, a2b1, a1b1, a0b1}`
   - Row 2 adds `{c4, s3, s2, s1}` from row 1 + the products with `b2`
   - Row 3 adds `{c4, s3, s2, s1}` from row 2 + the products with `b3`
3. `p0 = a0b0`, `p1` = s0 of row 1, `p2` = s0 of row 2,
   `p3..p6` = s0..s3 of row 3 and `p7` = final carry of row 3.

### Registers

```
ui_in --> [8 D FF] --> array multiplier --> [8 D FF] --> uo_out
```

16 D flip-flops form an input register and an output register. On every rising
edge of `clk` the data shifts one stage forward, so the product appears on `uo_out`
**2 clock cycles** after the operands are applied, and a new pair of operands can
be applied every cycle. Holding `rst_n` low clears both registers.

## How to test

1. Hold `rst_n` low for a few clock cycles, then set it high.
2. Set A on `ui_in[3:0]` and B on `ui_in[7:4]`.
3. After 2 clock cycles, read the product on `uo_out[7:0]`.

| A (ui_in[3:0]) | B (ui_in[7:4]) | ui_in      | uo_out (P)       |
|----------------|----------------|------------|------------------|
| 3              | 5              | `01010011` | `00001111` (15)  |
| 15             | 15             | `11111111` | `11100001` (225) |
| 7              | 2              | `00100111` | `00001110` (14)  |

## External hardware

None. DIP switches for the inputs and LEDs for the outputs are enough.
