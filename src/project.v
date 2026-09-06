/*
 * Copyright (c) 2026 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Tiny Tapeout Standart Silikon Kılıfı
module tt_um_example (
    input  wire [7:0] ui_in,    // Giriş Pinleri: ui_in[0] = START, ui_in[2:1] = Nöron Seçici
    output wire [7:0] uo_out,   // Çıkış Pinleri: Seçilen Nöronun 8-bitlik Çıktısı
    input  wire [7:0] uio_in,   // Kullanılmayan ek pinler
    output wire [7:0] uio_out,  // uio_out[0] = DONE Ledi!
    output wire [7:0] uio_oe,   // Pin Yönü (1 = Çıkış)
    input  wire       ena,      // Çip aktif
    input  wire       clk,      // Donanımsal Saat
    input  wire       rst_n     // Donanımsal Reset
);

    // uio_out[0] pinini DONE sinyali için çıkış yapıyoruz:
    assign uio_oe  = 8'b0000_0001;
    assign uio_out[7:1] = 7'b0;

    wire start_btn = ui_in[0];
    wire [1:0] neuron_sel = ui_in[2:1]; // Hangi nöronu görmek istiyorsun? (0, 1, 2, 3)

    // FSM Durumları
    localparam STATE_IDLE    = 2'd0;
    localparam STATE_COMPUTE = 2'd1;
    localparam STATE_DONE    = 2'd2;

    reg [1:0] current_state;
    reg [1:0] step_counter;
    reg       done_reg;
    reg signed [31:0] acc [0:3];
    reg signed [31:0] relu_out [0:3];

    assign uio_out[0] = done_reg;
    // Dışarıya seçilen nöronun ReLU sonucunu aktarıyoruz (0, 69, 54, 0):
    assign uo_out     = relu_out[neuron_sel][7:0];

    // --- GERÇEK SENTEZLENEBİLİR PYTORCH AĞIRLIKLARI (MANTIK KAPILARI) ---
    function [7:0] get_weight;
        input [1:0] core;
        input [1:0] step;
        begin
            case ({core, step})
                // Nöron 0
                4'b00_00: get_weight = 8'b10_01_01_01;
                4'b00_01: get_weight = 8'b10_00_10_01;
                4'b00_10: get_weight = 8'b10_10_01_10;
                // Nöron 1
                4'b01_00: get_weight = 8'b01_10_10_10;
                4'b01_01: get_weight = 8'b01_10_00_01;
                4'b01_10: get_weight = 8'b01_01_01_10;
                // Nöron 2
                4'b10_00: get_weight = 8'b01_01_01_01;
                4'b10_01: get_weight = 8'b01_00_00_00;
                4'b10_10: get_weight = 8'b01_00_10_10;
                // Nöron 3
                4'b11_00: get_weight = 8'b10_01_10_01;
                4'b11_01: get_weight = 8'b10_10_01_10;
                4'b11_10: get_weight = 8'b10_10_01_10;
                default:  get_weight = 8'h00;
            endcase
        end
    endfunction

    // Girdilerimiz
    reg signed [7:0] x0, x1, x2, x3;
    always @(*) begin
        case (step_counter)
            2'd0: begin x0 = 8'sd10; x1 = -8'sd5; x2 = 8'sd20; x3 = 8'sd4; end
            2'd1: begin x0 = 8'sd30; x1 = 8'sd2;  x2 = -8'sd10; x3 = 8'sd50; end
            2'd2: begin x0 = 8'sd15; x1 = 8'sd10; x2 = 8'sd5;  x3 = 8'sd0;  end
            default: begin x0 = 0; x1 = 0; x2 = 0; x3 = 0; end
        endcase
    end

    // Trit Fonksiyonu: Çarpma Devresi Yok!
    function signed [15:0] compute_trit;
        input signed [7:0] x;
        input [1:0] w;
        begin
            case (w)
                2'b01:   compute_trit = {{8{x[7]}}, x};
                2'b10:   compute_trit = -{{8{x[7]}}, x};
                default: compute_trit = 16'sd0;
            endcase
        end
    endfunction

    // 4 Paralel Çekirdeğin Kısmi Toplamları
    wire signed [15:0] psum [0:3];
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : CORE_GEN
            wire [7:0] w_byte = get_weight(i[1:0], step_counter);
            assign psum[i] = compute_trit(x0, w_byte[1:0]) +
                             compute_trit(x1, w_byte[3:2]) +
                             compute_trit(x2, w_byte[5:4]) +
                             compute_trit(x3, w_byte[7:6]);
        end
    endgenerate

    // FSM ve Akümülatör
    integer c;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
            step_counter  <= 2'd0;
            done_reg      <= 1'b0;
            for (c = 0; c < 4; c = c + 1) begin
                acc[c]      <= 32'sd0;
                relu_out[c] <= 32'sd0;
            end
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    done_reg     <= 1'b0;
                    step_counter <= 2'd0;
                    for (c = 0; c < 4; c = c + 1)
                        acc[c] <= 32'sd0;
                    if (start_btn)
                        current_state <= STATE_COMPUTE;
                end

                STATE_COMPUTE: begin
                    for (c = 0; c < 4; c = c + 1)
                        acc[c] <= acc[c] + {{16{psum[c][15]}}, psum[c]};

                    if (step_counter == 2'd2)
                        current_state <= STATE_DONE;
                    else
                        step_counter <= step_counter + 2'd1;
                end

                STATE_DONE: begin
                    done_reg <= 1'b1;
                    // Donanımsal ReLU
                    for (c = 0; c < 4; c = c + 1)
                        relu_out[c] <= (acc[c][31] == 1'b1) ? 32'sd0 : acc[c];

                    if (!start_btn)
                        current_state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
