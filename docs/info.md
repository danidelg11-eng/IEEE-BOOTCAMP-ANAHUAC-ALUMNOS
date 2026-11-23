<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This design implements a 24-hour digital clock, perpetual calendar (2000–2099), and programmable alarm using native BCD counters. A 24-bit prescaler divides the 10 MHz system clock down to 1 Hz, driving cascaded seconds, minutes, hours, days, months, and years registers. Combinational logic detects leap years by checking the BCD year digits for divisibility by 4 (`is_leap` on `uio_out[7]`), automatically adjusting February between 28 and 29 days while enforcing 30- and 31-day month limits. When `alarm_en` (`ui_in[6]`) is high and the current time matches the stored alarm time at second `00`, `alarm_ring` (`uio_out[6]`) latches high until `alarm_en` is cleared. A 6:1 time-division multiplexer drives six 7-segment digits (`uio_out[5:0]`) over a shared segment bus (`uo_out[7:0]`), allowing `view_mode` (`ui_in[1:0]`) to switch between Time (`HH.MM.SS`), Date (`DD.MM.AA`), and Alarm (`AL HH.MM`) views.

## How to test

Assert and release `rst_n` to initialize the clock to `00:00:00`, the date to `01.01.26`, and the default alarm to `AL 07.00`. Enable `fast_sim` (`ui_in[7] = 1`) to accelerate the 1 Hz tick to once every 16 clock cycles for rapid simulation, and toggle `view_mode` (`ui_in[1:0]`) across `00`, `01`, and `10` to verify the multiplexed outputs. To adjust values manually, set `edit_en` (`ui_in[2] = 1`), select a field with `field_sel` (`ui_in[4:3]`), and pulse `inc_btn` (`ui_in[5]`). Finally, verify leap-year rollover from `28.02.28` to `29.02.28` (`uio_out[7] = 1`) and confirm that `uio_out[6]` asserts high when the clock reaches the armed alarm time.

## External hardware

Connect a 6-digit common-cathode 7-segment display with `uo_out[7:0]` wired to segments `DP` and `G`–`A` through current-limiting resistors, and `uio_out[5:0]` connected to the digit cathodes via NPN transistors or a ULN2003 driver array. Control inputs require slide switches on `ui_in[4:0]` and `ui_in[7:6]`, along with a debounced pushbutton on `ui_in[5]` (`inc_btn`). Connect an active buzzer or LED to `uio_out[6]` for the alarm output and an indicator LED to `uio_out[7]` to display leap-year status.
