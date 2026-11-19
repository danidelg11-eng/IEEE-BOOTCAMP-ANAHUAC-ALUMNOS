/*
 * D flip-flop with active-low asynchronous reset.
 * On every rising edge of clk: q <= d. While rst_n = 0: q = 0.
 */
`default_nettype none

module d_ff (
    input  wire clk,
    input  wire rst_n,
    input  wire d,
    output reg  q
);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) q <= 1'b0;
    else        q <= d;
  end
endmodule
