<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

**How it works**
It's a 4-bit multiplier. You can enter the multiplicand and multiplier inputs in binary code; it makes a partial product, then performs an addition operation for each bit, and with the shift register, it saves the result. In a matter of 4 clock pulses, the result is displayed in binary code as well, across the 8 available outputs. The A inputs stand for the multiplicand, while the B inputs stand for the multiplier. There is a bidirectional input, LOAD, that shifts the data and saves the result.

**How to test**
The input pins from 0 to 3 correspond to the multiplicand, and the input pins from 4 to 7 are set for the multiplier. You have to set the operation with the desired values between 0 and 15 in binary. Afterwards, you need to activate the LOAD input, which saves the data, and then set LOAD to low so the product is displayed in binary code across the 8 available outputs. It takes 4 clock pulses to show the data.

## External hardware
VCC, leds and its respective pull out resistors
