module tt_um_4_bit_multiplier (
	input  wire [7:0] ui_in,
	output wire [7:0] uo_out,
	input  wire [7:0] uio_in,
	output wire [7:0] uio_out,
	output wire [7:0] uio_oe,   // Agrégalo aquí si lo vas a usar (estándar en Tiny Tapeout)
	input  wire       ena,
	input  wire       clk,
	input  wire       rst_n
);

	wire [3:0] A    = ui_in[7:4];
	wire [3:0] B    = ui_in[3:0];
	wire       load = uio_in[0];

	reg  [7:0] Q;
	reg  [2:0] count;

	// Corregido: {4{Q[0]}} en lugar de {A{Q[0]}}
	wire [3:0] PP = A & {4{Q[0]}};

	wire       Cout;
	wire [3:0] S;
	assign {Cout, S} = Q[7:4] + PP;

	// Corregido: Separación entre carga (load == 1) y desplazamiento (count < 4)
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			Q     <= 8'b0000_0000;
			count <= 3'd4;
		end else if (load) begin
			Q     <= {4'b0000, B};
			count <= 3'd0;
		end else if (count < 3'd4) begin
			Q     <= {Cout, S, Q[3:1]};
			count <= count + 3'd1;
		end
	end

	assign uo_out  = Q;

	// Corregido: uio_out con 't' al final
	assign uio_out = 8'b0000_0000;
	assign uio_oe  = 8'b0000_0000;
	
	// Corregido: espacio entre 'wire' y '_unused'
	wire _unused = &{ena, uio_in[7:1], 1'b0};

endmodule
