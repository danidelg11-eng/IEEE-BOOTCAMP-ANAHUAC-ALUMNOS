`default_nettype none

module tt_um_clock_calendar (
    input  wire [7:0] ui_in,    // Entradas dedicadas de control
    output wire [7:0] uo_out,   // Bus de 7 segmentos: {dp, g, f, e, d, c, b, a}
    input  wire [7:0] uio_in,   // IOs entrada (no usadas)
    output wire [7:0] uio_out,  // {is_leap, alarm_ring, digit_sel[5:0]}
    output wire [7:0] uio_oe,   // Todos configurados como salida (0xFF)
    input  wire       ena,      // Siempre 1 cuando el diseño está activo
    input  wire       clk,      // Reloj del sistema (por defecto 10 MHz)
    input  wire       rst_n     // Reset síncrono/asíncrono activo en bajo
);

    // Parámetro de división para 1 Hz (10,000,000 ciclos @ 10 MHz)
    localparam [23:0] CLK_FREQ_HZ = 24'd10_000_000;

    // Modos de visualización
    localparam [1:0] MODE_TIME  = 2'd0;
    localparam [1:0] MODE_DATE  = 2'd1;
    localparam [1:0] MODE_ALARM = 2'd2;

    // Caracteres especiales {g, f, e, d, c, b, a} (cátodo común)
    localparam [6:0] SEG_A     = 7'b1110111; // A
    localparam [6:0] SEG_L     = 7'b0111000; // L
    localparam [6:0] SEG_BLANK = 7'b0000000; // Apagado

    // Mapeo de entradas
    wire [1:0] view_mode = ui_in[1:0];
    wire       edit_en   = ui_in[2];
    wire [1:0] field_sel = ui_in[4:3];
    wire       inc_btn   = ui_in[5];
    wire       alarm_en  = ui_in[6];
    wire       fast_sim  = ui_in[7];

    // Registros de tiempo, fecha y alarma (en BCD para ahorrar decodificadores)
    reg [3:0] sec_u, sec_t;     // Segundos: 00 - 59
    reg [3:0] min_u, min_t;     // Minutos:  00 - 59
    reg [3:0] hr_u,  hr_t;      // Horas:    00 - 23

    reg [3:0] day_u, day_t;     // Día:      01 - 28/29/30/31
    reg [3:0] mon_u, mon_t;     // Mes:      01 - 12
    reg [3:0] yr_u,  yr_t;      // Año:      00 - 99 (2000 - 2099)

    reg [3:0] al_min_u, al_min_t; // Alarma Minutos: 00 - 59
    reg [3:0] al_hr_u,  al_hr_t;  // Alarma Horas:   00 - 23

    // Prescaler y control de multiplexado
    reg [23:0] prescaler;
    reg [15:0] mux_div;
    reg [2:0]  mux_sel;
    reg        alarm_ring;

    // Detector de flanco para inc_btn
    reg  inc_btn_d;
    wire inc_pulse = inc_btn & ~inc_btn_d;

    // --- DETECCIÓN DE AÑO BISIESTO (2000 - 2099 en BCD) ---
    // Un año 20XX es bisiesto si XX es múltiplo de 4:
    // En BCD: (decenas par y unidades in {0,4,8}) O (decenas impar y unidades in {2,6})
    wire yr_tens_odd = yr_t[0];
    wire is_leap = (!yr_tens_odd && (yr_u == 4'd0 || yr_u == 4'd4 || yr_u == 4'd8)) ||
                   ( yr_tens_odd && (yr_u == 4'd2 || yr_u == 4'd6));

    // --- CÁLCULO DEL ÚLTIMO DÍA DEL MES ACTUAL ---
    reg [3:0] max_day_t, max_day_u;
    always @(*) begin
        if (mon_t == 4'd0 && mon_u == 4'd2) begin
            // Febrero: 29 si es bisiesto, 28 si no
            max_day_t = 4'd2;
            max_day_u = is_leap ? 4'd9 : 4'd8;
        end else if ((mon_t == 4'd0 && (mon_u == 4'd4 || mon_u == 4'd6 || mon_u == 4'd9)) ||
                     (mon_t == 4'd1 &&  mon_u == 4'd1)) begin
            // Abril (04), Junio (06), Septiembre (09), Noviembre (11) -> 30 días
            max_day_t = 4'd3;
            max_day_u = 4'd0;
        end else begin
            // Resto de meses -> 31 días
            max_day_t = 4'd3;
            max_day_u = 4'd1;
        end
    end

    // Pulso de 1 segundo (normal o acelerado para simulación)
    wire tick_1hz = fast_sim ? (prescaler[3:0] == 4'hF) : (prescaler == (CLK_FREQ_HZ - 24'd1));

    // Señales de acarreo combinacionales
    wire sec_max = (sec_t == 4'd5) && (sec_u == 4'd9);
    wire min_max = (min_t == 4'd5) && (min_u == 4'd9);
    wire hr_max  = (hr_t  == 4'd2) && (hr_u  == 4'd3);
    wire day_max = (day_t == max_day_t) && (day_u == max_day_u);
    wire mon_max = (mon_t == 4'd1) && (mon_u == 4'd2);
    wire yr_max  = (yr_t  == 4'd9) && (yr_u  == 4'd9);

    // Coincidencia de alarma (en el segundo 00)
    wire alarm_match = (hr_t == al_hr_t) && (hr_u == al_hr_u) &&
                       (min_t == al_min_t) && (min_u == al_min_u) &&
                       (sec_t == 4'd0) && (sec_u == 4'd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Inicialización: 00:00:00 del 01/01/26, Alarma a las 07:00
            sec_u <= 4'd0; sec_t <= 4'd0;
            min_u <= 4'd0; min_t <= 4'd0;
            hr_u  <= 4'd0; hr_t  <= 4'd0;

            day_u <= 4'd1; day_t <= 4'd0;
            mon_u <= 4'd1; mon_t <= 4'd0;
            yr_u  <= 4'd6; yr_t  <= 4'd2; // Año 26 (2026)

            al_min_u <= 4'd0; al_min_t <= 4'd0;
            al_hr_u  <= 4'd7; al_hr_t  <= 4'd0;

            prescaler  <= 24'd0;
            mux_div    <= 16'd0;
            mux_sel    <= 3'd0;
            inc_btn_d  <= 1'b0;
            alarm_ring <= 1'b0;
        end else begin
            inc_btn_d <= inc_btn;

            // Barrido de displays (~1 kHz en hardware, cada 4 ciclos en fast_sim)
            mux_div <= mux_div + 16'd1;
            if ((fast_sim && mux_div[1:0] == 2'b11) || (!fast_sim && mux_div == 16'd9999)) begin
                mux_div <= 16'd0;
                mux_sel <= (mux_sel == 3'd5) ? 3'd0 : (mux_sel + 3'd1);
            end

            // Control de disparo y apagado de alarma
            if (!alarm_en) begin
                alarm_ring <= 1'b0;
            end else if (!edit_en && tick_1hz && alarm_match) begin
                alarm_ring <= 1'b1;
            end

            // --- MODO AJUSTE MANUAL (edit_en == 1) ---
            if (edit_en) begin
                prescaler <= 24'd0;
                if (inc_pulse) begin
                    case (view_mode)
                        MODE_TIME: begin
                            if (field_sel == 2'd0) begin // Ajustar Horas
                                if (hr_max) begin hr_t <= 4'd0; hr_u <= 4'd0; end
                                else if (hr_u == 4'd9) begin hr_u <= 4'd0; hr_t <= hr_t + 4'd1; end
                                else hr_u <= hr_u + 4'd1;
                            end else if (field_sel == 2'd1) begin // Ajustar Minutos
                                if (min_max) begin min_t <= 4'd0; min_u <= 4'd0; end
                                else if (min_u == 4'd9) begin min_u <= 4'd0; min_t <= min_t + 4'd1; end
                                else min_u <= min_u + 4'd1;
                            end else begin // Reiniciar Segundos a 00
                                sec_t <= 4'd0; sec_u <= 4'd0;
                            end
                        end

                        MODE_DATE: begin
                            if (field_sel == 2'd0) begin // Ajustar Día
                                if (day_max) begin day_t <= 4'd0; day_u <= 4'd1; end
                                else if (day_u == 4'd9) begin day_u <= 4'd0; day_t <= day_t + 4'd1; end
                                else day_u <= day_u + 4'd1;
                            end else if (field_sel == 2'd1) begin // Ajustar Mes
                                if (mon_max) begin mon_t <= 4'd0; mon_u <= 4'd1; end
                                else if (mon_u == 4'd9) begin mon_u <= 4'd0; mon_t <= mon_t + 4'd1; end
                                else mon_u <= mon_u + 4'd1;
                            end else begin // Ajustar Año
                                if (yr_max) begin yr_t <= 4'd0; yr_u <= 4'd0; end
                                else if (yr_u == 4'd9) begin yr_u <= 4'd0; yr_t <= yr_t + 4'd1; end
                                else yr_u <= yr_u + 4'd1;
                            end
                        end

                        MODE_ALARM: begin
                            if (field_sel == 2'd0) begin // Ajustar Horas Alarma
                                if ((al_hr_t == 4'd2) && (al_hr_u == 4'd3)) begin
                                    al_hr_t <= 4'd0; al_hr_u <= 4'd0;
                                end else if (al_hr_u == 4'd9) begin
                                    al_hr_u <= 4'd0; al_hr_t <= al_hr_t + 4'd1;
                                end else al_hr_u <= al_hr_u + 4'd1;
                            end else begin // Ajustar Minutos Alarma
                                if ((al_min_t == 4'd5) && (al_min_u == 4'd9)) begin
                                    al_min_t <= 4'd0; al_min_u <= 4'd0;
                                end else if (al_min_u == 4'd9) begin
                                    al_min_u <= 4'd0; al_min_t <= al_min_t + 4'd1;
                                end else al_min_u <= al_min_u + 4'd1;
                            end
                        end
                        default: ;
                    endcase
                end
            end else begin
                // --- CONTEO AUTOMÁTICO NORMAL (edit_en == 0) ---
                if (tick_1hz) begin
                    prescaler <= 24'd0;

                    // Segundos
                    if (sec_max) begin
                        sec_t <= 4'd0; sec_u <= 4'd0;
                        // Minutos
                        if (min_max) begin
                            min_t <= 4'd0; min_u <= 4'd0;
                            // Horas
                            if (hr_max) begin
                                hr_t <= 4'd0; hr_u <= 4'd0;
                                // Días
                                if (day_max) begin
                                    day_t <= 4'd0; day_u <= 4'd1;
                                    // Meses
                                    if (mon_max) begin
                                        mon_t <= 4'd0; mon_u <= 4'd1;
                                        // Años
                                        if (yr_max) begin
                                            yr_t <= 4'd0; yr_u <= 4'd0;
                                        end else if (yr_u == 4'd9) begin
                                            yr_u <= 4'd0; yr_t <= yr_t + 4'd1;
                                        end else begin
                                            yr_u <= yr_u + 4'd1;
                                        end
                                    end else if (mon_u == 4'd9) begin
                                        mon_u <= 4'd0; mon_t <= mon_t + 4'd1;
                                    end else begin
                                        mon_u <= mon_u + 4'd1;
                                    end
                                end else if (day_u == 4'd9) begin
                                    day_u <= 4'd0; day_t <= day_t + 4'd1;
                                end else begin
                                    day_u <= day_u + 4'd1;
                                end
                            end else if (hr_u == 4'd9) begin
                                hr_u <= 4'd0; hr_t <= hr_t + 4'd1;
                            end else begin
                                hr_u <= hr_u + 4'd1;
                            end
                        end else if (min_u == 4'd9) begin
                            min_u <= 4'd0; min_t <= min_t + 4'd1;
                        end else begin
                            min_u <= min_u + 4'd1;
                        end
                    end else if (sec_u == 4'd9) begin
                        sec_u <= 4'd0; sec_t <= sec_t + 4'd1;
                    end else begin
                        sec_u <= sec_u + 4'd1;
                    end
                end else begin
                    prescaler <= prescaler + 24'd1;
                end
            end
        end
    end

    // Decodificador BCD (0-9) a 7 segmentos {g, f, e, d, c, b, a}
    function [6:0] bcd_to_7seg;
        input [3:0] bcd;
        begin
            case (bcd)
                4'd0: bcd_to_7seg = 7'b0111111;
                4'd1: bcd_to_7seg = 7'b0000110;
                4'd2: bcd_to_7seg = 7'b1011011;
                4'd3: bcd_to_7seg = 7'b1001111;
                4'd4: bcd_to_7seg = 7'b1100110;
                4'd5: bcd_to_7seg = 7'b1101101;
                4'd6: bcd_to_7seg = 7'b1111101;
                4'd7: bcd_to_7seg = 7'b0000111;
                4'd8: bcd_to_7seg = 7'b1111111;
                4'd9: bcd_to_7seg = 7'b1101111;
                default: bcd_to_7seg = 7'b0000000;
            endcase
        end
    endfunction

    // Selección de los 6 dígitos a mostrar (d5 = izquierda ... d0 = derecha)
    reg [6:0] seg5, seg4, seg3, seg2, seg1, seg0;
    always @(*) begin
        case (view_mode)
            MODE_DATE: begin
                seg5 = bcd_to_7seg(day_t);
                seg4 = bcd_to_7seg(day_u);
                seg3 = bcd_to_7seg(mon_t);
                seg2 = bcd_to_7seg(mon_u);
                seg1 = bcd_to_7seg(yr_t);
                seg0 = bcd_to_7seg(yr_u);
            end
            MODE_ALARM: begin
                // Muestra "AL HH.MM"
                seg5 = SEG_A;
                seg4 = SEG_L;
                seg3 = bcd_to_7seg(al_hr_t);
                seg2 = bcd_to_7seg(al_hr_u);
                seg1 = bcd_to_7seg(al_min_t);
                seg0 = bcd_to_7seg(al_min_u);
            end
            default: begin // MODE_TIME: HH.MM.SS
                seg5 = bcd_to_7seg(hr_t);
                seg4 = bcd_to_7seg(hr_u);
                seg3 = bcd_to_7seg(min_t);
                seg2 = bcd_to_7seg(min_u);
                seg1 = bcd_to_7seg(sec_t);
                seg0 = bcd_to_7seg(sec_u);
            end
        endcase
    end

    // Multiplexor 6:1 de displays (dp separa pares: HH.MM.SS y DD.MM.AA)
    reg [6:0] active_seg;
    reg       active_dp;
    reg [5:0] digit_sel;

    always @(*) begin
        case (mux_sel)
            3'd0: begin active_seg = seg5; active_dp = 1'b0; digit_sel = 6'b100000; end
            3'd1: begin active_seg = seg4; active_dp = (view_mode != MODE_ALARM); digit_sel = 6'b010000; end
            3'd2: begin active_seg = seg3; active_dp = 1'b0; digit_sel = 6'b001000; end
            3'd3: begin active_seg = seg2; active_dp = 1'b1; digit_sel = 6'b000100; end
            3'd4: begin active_seg = seg1; active_dp = 1'b0; digit_sel = 6'b000010; end
            default: begin active_seg = seg0; active_dp = 1'b0; digit_sel = 6'b000001; end
        endcase
    end

    assign uo_out  = {active_dp, active_seg};
    assign uio_out = {is_leap, alarm_ring, digit_sel};
    assign uio_oe  = 8'hFF;

    wire _unused = &{ena, uio_in, 1'b0};

endmodule
