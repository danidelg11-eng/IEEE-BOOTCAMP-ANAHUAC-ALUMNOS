
module tt_um_digital_safe (
input  wire [7:0] ui_in,    // Entradas dedicadas
    output wire [7:0] uo_out,   // Display 1 de 7 segmentos: {dp, g, f, e, d, c, b, a}
    output wire [7:0] uo_out,   // Bus compartido de 7 segmentos: {dp, g, f, e, d, c, b, a}
input  wire [7:0] uio_in,   // IOs entrada (no usadas)
    output wire [7:0] uio_out,  // Display 2 de 7 segmentos: {dp, g, f, e, d, c, b, a}
    output wire [7:0] uio_oe,   // Habilitación de IOs (1 = salida)
    output wire [7:0] uio_out,  // {alarm, unlocked, status[1:0], digit_sel[3:0]}
    output wire [7:0] uio_oe,   // Todos como salida (0xFF)
input  wire       ena,      // Siempre 1 cuando el chip está encendido
input  wire       clk,      // Reloj
    input  wire       rst_n     // Reset activo en bajo
    input  wire       rst_n     // Reset activo en bajo (también libera LOCKOUT)
);

    // Contraseña inicial tras reset
    localparam [3:0] PIN_DEFAULT = 4'hA;
    // Contraseña inicial de 4 dígitos hexadecimales (16 bits)
    localparam [15:0] PIN_DEFAULT = 16'h1234;

// Estados de la FSM
localparam [1:0] S_LOCKED   = 2'd0;
localparam [1:0] S_UNLOCKED = 2'd1;
localparam [1:0] S_LOCKOUT  = 2'd2;

    // Tipos de evento en el registro de accesos
    // Códigos de evento en el registro de accesos
localparam [1:0] EVT_EMPTY   = 2'd0;
localparam [1:0] EVT_GRANTED = 2'd1;
localparam [1:0] EVT_DENIED  = 2'd2;
localparam [1:0] EVT_LOCKOUT = 2'd3;

    // Caracteres especiales en 7 segmentos {g, f, e, d, c, b, a} (cátodo común)
    localparam [6:0] SEG_U    = 7'b0111110; // U (Abierta)
    localparam [6:0] SEG_L    = 7'b0111000; // L (Bloqueada)
    localparam [6:0] SEG_P    = 7'b1110011; // P (Programar contraseña)
    localparam [6:0] SEG_DASH = 7'b1000000; // - (Registro vacío)
    localparam [6:0] SEG_A    = 7'b1110111; // A (Acceso aceptado)
    localparam [6:0] SEG_D    = 7'b1011110; // d (Acceso denegado)
    localparam [6:0] SEG_E    = 7'b1111001; // E (Error / Bloqueo)
    // Caracteres especiales para los 4 displays {g, f, e, d, c, b, a} (cátodo común)
    localparam [6:0] SEG_0    = 7'b0111111; // 0 / O
    localparam [6:0] SEG_P    = 7'b1110011; // P
    localparam [6:0] SEG_E    = 7'b1111001; // E
    localparam [6:0] SEG_N    = 7'b1010100; // n
    localparam [6:0] SEG_L    = 7'b0111000; // L
    localparam [6:0] SEG_o    = 7'b1011100; // o
    localparam [6:0] SEG_C    = 7'b0111001; // C
    localparam [6:0] SEG_d    = 7'b1011110; // d
    localparam [6:0] SEG_DASH = 7'b1000000; // -

// Mapeo de entradas
    wire [3:0] key_in    = ui_in[3:0];
    wire       enter_btn = ui_in[4];
    wire       lock_btn  = ui_in[5];
    wire       log_mode  = ui_in[6];
    wire       prog_mode = ui_in[7];
    wire [2:0] log_addr  = ui_in[2:0];
    wire [3:0] key_in         = ui_in[3:0];
    wire       load_btn       = ui_in[4];
    wire       enter_lock_btn = ui_in[5];
    wire       log_mode       = ui_in[6];
    wire       prog_mode      = ui_in[7];
    wire [1:0] log_addr       = ui_in[1:0];

// Registros internos
    reg [1:0] state;
    reg [3:0] current_pin;
    reg [1:0] attempts_left;
    reg [2:0] log_wr_ptr;
    reg [1:0]  state;
    reg [15:0] current_pin;
    reg [15:0] pin_buf;
    reg [1:0]  attempts_left;
    reg [1:0]  log_wr_ptr;
    reg [1:0]  mux_sel;

    // Buffer circular de 8 accesos: {tipo_evento[1:0], codigo_hex[3:0]}
    reg [5:0] access_log [0:7];
    // Buffer circular de 4 accesos: {tipo_evento[1:0], pin_intentado[15:0]}
    reg [17:0] access_log [0:3];

// Detectores de flanco de subida
    reg enter_btn_d;
    reg lock_btn_d;
    wire enter_pulse = enter_btn & ~enter_btn_d;
    wire lock_pulse  = lock_btn  & ~lock_btn_d;
    reg load_btn_d;
    reg enter_lock_btn_d;
    wire load_pulse       = load_btn       & ~load_btn_d;
    wire enter_lock_pulse = enter_lock_btn & ~enter_lock_btn_d;

integer i;

    // Lógica secuencial
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
            state         <= S_LOCKED;
            current_pin   <= PIN_DEFAULT;
            attempts_left <= 2'd3;
            log_wr_ptr    <= 3'd0;
            enter_btn_d   <= 1'b0;
            lock_btn_d    <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                access_log[i] <= 6'b00_0000;
            state            <= S_LOCKED;
            current_pin      <= PIN_DEFAULT;
            pin_buf          <= 16'h0000;
            attempts_left    <= 2'd3;
            log_wr_ptr       <= 2'd0;
            mux_sel          <= 2'd0;
            load_btn_d       <= 1'b0;
            enter_lock_btn_d <= 1'b0;
            for (i = 0; i < 4; i = i + 1) begin
                access_log[i] <= 18'd0;
end
end else begin
            enter_btn_d <= enter_btn;
            lock_btn_d  <= lock_btn;
            // Rotación de los 4 displays multiplexados (izquierda a derecha)
            mux_sel          <= mux_sel + 2'd1;
            load_btn_d       <= load_btn;
            enter_lock_btn_d <= enter_lock_btn;

if (!log_mode) begin
case (state)
S_LOCKED: begin
                        if (enter_pulse) begin
                            if (key_in == current_pin) begin
                        if (load_pulse) begin
                            pin_buf <= {pin_buf[11:0], key_in};
                        end else if (enter_lock_pulse) begin
                            if (pin_buf == current_pin) begin
state                  <= S_UNLOCKED;
attempts_left          <= 2'd3;
                                access_log[log_wr_ptr] <= {EVT_GRANTED, key_in};
                                access_log[log_wr_ptr] <= {EVT_GRANTED, pin_buf};
end else begin
if (attempts_left == 2'd1) begin
state                  <= S_LOCKOUT;
attempts_left          <= 2'd0;
                                    access_log[log_wr_ptr] <= {EVT_LOCKOUT, key_in};
                                    access_log[log_wr_ptr] <= {EVT_LOCKOUT, pin_buf};
end else begin
attempts_left          <= attempts_left - 2'd1;
                                    access_log[log_wr_ptr] <= {EVT_DENIED, key_in};
                                    access_log[log_wr_ptr] <= {EVT_DENIED, pin_buf};
end
end
                            log_wr_ptr <= log_wr_ptr + 3'd1;
                            log_wr_ptr <= log_wr_ptr + 2'd1;
                            pin_buf    <= 16'h0000;
end
end

S_UNLOCKED: begin
                        if (prog_mode && enter_pulse) begin
                            // Guarda la nueva contraseña de 4 bits
                            current_pin <= key_in;
                        end else if (lock_pulse) begin
                            state <= S_LOCKED;
                        if (prog_mode) begin
                            if (load_pulse) begin
                                pin_buf <= {pin_buf[11:0], key_in};
                            end else if (enter_lock_pulse) begin
                                current_pin <= pin_buf;
                            end
                        end else if (enter_lock_pulse) begin
                            state   <= S_LOCKED;
                            pin_buf <= 16'h0000;
end
end

@@ -144,48 +158,69 @@ module tt_um_digital_safe (
end
endfunction

    // Lectura del registro seleccionado
    wire [5:0] selected_log  = access_log[log_addr];
    wire [1:0] selected_evt  = selected_log[5:4];
    wire [3:0] selected_code = selected_log[3:0];
    // Lectura del historial seleccionado
    wire [17:0] selected_log = access_log[log_addr];
    wire [1:0]  selected_evt = selected_log[17:16];
    wire [15:0] selected_pin = selected_log[15:0];

    reg [6:0] disp1_seg;
    reg       disp1_dp;
    reg [6:0] disp2_seg;
    reg       disp2_dp;
    reg [6:0] seg3, seg2, seg1, seg0;
    reg [6:0] active_seg;
    reg       active_dp;
    reg [3:0] digit_sel;

    // Multiplexado de salidas para los 2 displays
    // Selección del texto o dígitos para los 4 displays (seg3 = izquierda, seg0 = derecha)
always @(*) begin
if (log_mode) begin
            disp1_seg = (selected_evt == EVT_EMPTY) ? SEG_DASH : hex_to_7seg(selected_code);
            disp1_dp  = 1'b1;

            case (selected_evt)
                EVT_GRANTED: begin disp2_seg = SEG_A;    disp2_dp = 1'b1; end
                EVT_DENIED:  begin disp2_seg = SEG_D;    disp2_dp = 1'b1; end
                EVT_LOCKOUT: begin disp2_seg = SEG_E;    disp2_dp = 1'b1; end
                default:     begin disp2_seg = SEG_DASH; disp2_dp = 1'b0; end
            endcase
            if (selected_evt == EVT_EMPTY) begin
                seg3 = SEG_DASH;
                seg2 = SEG_DASH;
                seg1 = SEG_DASH;
                seg0 = SEG_DASH;
            end else begin
                seg3 = hex_to_7seg(selected_pin[15:12]);
                seg2 = hex_to_7seg(selected_pin[11:8]);
                seg1 = hex_to_7seg(selected_pin[7:4]);
                seg0 = hex_to_7seg(selected_pin[3:0]);
            end
end else if ((state == S_UNLOCKED) && prog_mode) begin
            // Modo programación: Display 1 = nuevo dígito elegido | Display 2 = 'P.'
            disp1_seg = hex_to_7seg(key_in);
            disp1_dp  = 1'b1;
            disp2_seg = SEG_P;
            disp2_dp  = 1'b1;
            seg3 = hex_to_7seg(pin_buf[15:12]);
            seg2 = hex_to_7seg(pin_buf[11:8]);
            seg1 = hex_to_7seg(pin_buf[7:4]);
            seg0 = hex_to_7seg(pin_buf[3:0]);
        end else if (state == S_UNLOCKED) begin
            // Deletrea "0PEn"
            seg3 = SEG_0;
            seg2 = SEG_P;
            seg1 = SEG_E;
            seg0 = SEG_N;
        end else if (state == S_LOCKOUT) begin
            // Deletrea "LoCd"
            seg3 = SEG_L;
            seg2 = SEG_o;
            seg1 = SEG_C;
            seg0 = SEG_d;
end else begin
            case (state)
                S_UNLOCKED: begin disp1_seg = SEG_U;               disp1_dp = 1'b1; end
                S_LOCKOUT:  begin disp1_seg = SEG_L;               disp1_dp = 1'b0; end
                default:    begin disp1_seg = hex_to_7seg(key_in); disp1_dp = 1'b0; end
            endcase

            disp2_seg = hex_to_7seg({2'b00, attempts_left});
            disp2_dp  = (state == S_LOCKOUT);
            seg3 = hex_to_7seg(pin_buf[15:12]);
            seg2 = hex_to_7seg(pin_buf[11:8]);
            seg1 = hex_to_7seg(pin_buf[7:4]);
            seg0 = hex_to_7seg(pin_buf[3:0]);
end
end

    assign uo_out  = {disp1_dp, disp1_seg};
    assign uio_out = {disp2_dp, disp2_seg};
    // Multiplexor de salida para los 4 displays (dp=1 marca siempre el 1.er dígito)
    always @(*) begin
        case (mux_sel)
            2'd0: begin active_seg = seg3; active_dp = 1'b1; digit_sel = 4'b1000; end
            2'd1: begin active_seg = seg2; active_dp = 1'b0; digit_sel = 4'b0100; end
            2'd2: begin active_seg = seg1; active_dp = 1'b0; digit_sel = 4'b0010; end
            default: begin active_seg = seg0; active_dp = 1'b0; digit_sel = 4'b0001; end
        endcase
    end

    wire [1:0] status_bits = log_mode ? selected_evt : attempts_left;

    assign uo_out  = {active_dp, active_seg};
    assign uio_out = {(state == S_LOCKOUT), (state == S_UNLOCKED), status_bits, digit_sel};
assign uio_oe  = 8'hFF;

wire _unused = &{ena, uio_in, 1'b0};
