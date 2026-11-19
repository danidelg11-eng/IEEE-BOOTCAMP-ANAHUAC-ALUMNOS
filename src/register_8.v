/*
 * 8-bit register built from 8 D flip-flops.
 */
`default_nettype none

module register_8 (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] d,
    output wire [7:0] q
);
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : ff
      d_ff u_ff (.clk(clk), .rst_n(rst_n), .d(d[i]), .q(q[i]));
    end
  endgenerate
endmodule
