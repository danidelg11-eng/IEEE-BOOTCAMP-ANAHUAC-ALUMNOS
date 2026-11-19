/*
 * Copyright (c) 2026 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// ==================================================
// PROJECT: 4-BIT BINARY MULTIPLIER
// TOP MODULE: tt_um_multiplicador_4bits
// PLATFORM: TINY TAPEOUT
//
// INPUT:  ui_in[7:0] = {A[3:0], B[3:0]}  (one 8-bit bus, two 4-bit operands)
// OUTPUT: uo_out[7:0] = A * B            (8-bit unsigned product)
// STORAGE: 8 D-type flip-flops (output register)
//
// OPERATION:
// The multiplication is combinational (4 partial products + adder).
// The result is stored on each rising clock edge, so the product
// appears on uo_out ONE clock cycle after the operands are applied.
// rst_n (active low, asynchronous) clears the output register to 0.
// ==================================================

module tt_um_multiplicador_4bits (
    input  wire [7:0] ui_in,    // Dedicated inputs: {A, B}
    output wire [7:0] uo_out,   // Dedicated outputs: product
    input  wire [7:0] uio_in,   // IOs: Input path (unused)
    output wire [7:0] uio_out,  // IOs: Output path (unused)
    output wire [7:0] uio_oe,   // IOs: Enable path (0 = input)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // ==============================================
    // 1. INPUT OPERANDS
    // ==============================================

    wire [3:0] A;
    wire [3:0] B;

    assign A = ui_in[7:4];
    assign B = ui_in[3:0];


    // ==============================================
    // 2. PARTIAL PRODUCT GENERATION
    // ==============================================

    wire [7:0] pp0;
    wire [7:0] pp1;
    wire [7:0] pp2;
    wire [7:0] pp3;

    assign pp0 = {4'b0000, (A & {4{B[0]}})};

    assign pp1 = {3'b000, (A & {4{B[1]}}), 1'b0};

    assign pp2 = {2'b00, (A & {4{B[2]}}), 2'b00};

    assign pp3 = {1'b0, (A & {4{B[3]}}), 3'b000};


    // ==============================================
    // 3. PARTIAL PRODUCT ADDITION
    // ==============================================

    wire [7:0] product_comb;

    assign product_comb = pp0 + pp1 + pp2 + pp3;


    // ==============================================
    // 4. D-TYPE FLIP-FLOP OUTPUT REGISTER
    // ==============================================

    reg [7:0] product_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product_reg <= 8'b00000000;
        end else begin
            product_reg <= product_comb;
        end
    end


    // ==============================================
    // 5. OUTPUT ASSIGNMENT
    // ==============================================

    assign uo_out = product_reg;


    // ==============================================
    // 6. UNUSED BIDIRECTIONAL PINS
    // ==============================================

    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;


    // ==============================================
    // 7. UNUSED INPUT SIGNALS
    // ==============================================

    // The leading underscore tells the linter this wire is intentionally unused.
    wire _unused = &{ena, uio_in, 1'b0};

endmodule

`default_nettype wire

