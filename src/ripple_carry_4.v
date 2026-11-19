/*
 * 4-bit ripple-carry adder: 4 chained full adders
 * (fa0 -> fa1 -> fa2 -> fa3). Each one is a "Row" of the schematic.
 */
`default_nettype none

module ripple_carry_4 (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire       ci,
    output wire [3:0] s,
    output wire       co    // c4
);
  wire c1, c2, c3;

  full_adder fa0 (.a(a[0]), .b(b[0]), .ci(ci), .s(s[0]), .co(c1));
  full_adder fa1 (.a(a[1]), .b(b[1]), .ci(c1), .s(s[1]), .co(c2));
  full_adder fa2 (.a(a[2]), .b(b[2]), .ci(c2), .s(s[2]), .co(c3));
  full_adder fa3 (.a(a[3]), .b(b[3]), .ci(c3), .s(s[3]), .co(co));
endmodule
