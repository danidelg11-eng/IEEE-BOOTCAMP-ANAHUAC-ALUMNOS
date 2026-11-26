<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works
It´s a 4 bit multiplier, you can enter in binary code the multiplying and multiplying inputs, it makes a half-product, then it realizes an addition operation for each bit, and with the shift register, saves the result, and in a matter of 4 clock pulses, the result is displayed, in binary code, as well, throughout the 8 available outputs.The A inputs stand for the multiplying, while the B inputs stand for the multiplier. There is a bidirectional input, LOAD, that shifts the data and saves the result.

## How to test
The input pins from 0 to 3, correspond to the multipliplying, and the input pins from 4 to 7, are set for the multiplier, you gotta set the operation with the desired values betweeen 0 and 15 in binary. Afterwise, you need to activate the LOAD entry, that saves the data, then you have to put LOAD in low, so the product is displayed, in binary code, through the 8 available outputs. It takes 4 clock pulses to show the data.
## External hardware
VCC, leds and its respective pull out resistors
