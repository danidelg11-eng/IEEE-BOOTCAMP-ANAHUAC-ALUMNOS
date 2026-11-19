/*
 * 1-bit full adder (FA)
 *   s  = a XOR b XOR ci
 *   co = (a AND b) OR (ci AND (a XOR b))
 */
`default_nettype none

module full_adder (
    input  wire a,
    input  wire b,
    input  wire ci,
    output wire s,
    output wire co
);
  wire axb = a ^ b;

  assign s  = axb ^ ci;
  assign co = (a & b) | (ci & axb);
endmodule
