`default_nettype none
`timescale 1ns / 1ps

// ==================================================
// TESTBENCH: 4-BIT BINARY MULTIPLIER
// TOP MODULE: tt_um_multiplicador_4bits
// ==================================================

module tb ();

    // ==============================================
    // WAVEFORM GENERATION
    // ==============================================

    initial begin
        $dumpfile("tb.fst");
        $dumpvars(0, tb);
        #1;
    end

    // ==============================================
    // INPUT SIGNALS
    // ==============================================

    reg clk;
    reg rst_n;
    reg ena;

    reg [7:0] ui_in;
    reg [7:0] uio_in;

    // ==============================================
    // OUTPUT SIGNALS
    // ==============================================

    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // ==============================================
    // GATE LEVEL POWER CONNECTIONS
    // ==============================================

`ifdef GL_TEST

    wire VPWR = 1'b1;
    wire VGND = 1'b0;

`endif

    // ==============================================
    // DESIGN UNDER TEST
    // ==============================================

    tt_um_multiplicador_4bits user_project (

`ifdef GL_TEST

        .VPWR(VPWR),
        .VGND(VGND),

`endif

        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (ena),
        .clk     (clk),
        .rst_n   (rst_n)

    );

endmodule

`default_nettype wire
