`default_nettype none

// ==================================================
// PROJECT: 4-BIT BINARY MULTIPLIER
// TOP MODULE: tt_um_multiplicador_4bits
// PLATFORM: TINY TAPEOUT
// ==================================================

module tt_um_multiplicador_4bits (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // ==============================================
    // INPUT OPERANDS
    // ==============================================

    wire [3:0] A;
    wire [3:0] B;

    assign A = ui_in[7:4];
    assign B = ui_in[3:0];

    // ==============================================
    // PARTIAL PRODUCT GENERATION
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
    // ADD PARTIAL PRODUCTS
    // ==============================================

    wire [7:0] product_comb;

    assign product_comb = pp0 + pp1 + pp2 + pp3;

    // ==============================================
    // D-TYPE FLIP-FLOP OUTPUT REGISTER
    // ==============================================

    reg [7:0] product_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            product_reg <= 8'b00000000;
        else
            product_reg <= product_comb;
    end

    // ==============================================
    // OUTPUT PINS
    // ==============================================

    assign uo_out = product_reg;

    // ==============================================
    // UNUSED BIDIRECTIONAL PINS
    // ==============================================

    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    // ==============================================
    // UNUSED INPUT SIGNALS
    // ==============================================

    wire unused;
    assign unused = &{ena, uio_in};

endmodule

`default_nettype wire
