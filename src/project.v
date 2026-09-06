/*
 * Copyright (c) 2026 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Tiny Tapeout Standart Silikon Kılıfı
module tt_um_example (
    input  wire [7:0] ui_in,    // Giriş Pinleri: ui_in[0] = START, ui_in[2:1] = Nöron Seçimi
    output wire [7:0] uo_out,   // Çıkış Pinleri: Nöron Çıktısı (0, 69, 54, 0)
    input  wire [7:0] uio_in,   // Kullanılmayan ek girişler
    output wire [7:0] uio_out,  // uio_out[0] = DONE sinyali
    output wire [7:0] uio_oe,   // Pin yönlendirme
    input  wire       ena,      // Çip aktif pini
    input  wire       clk,      // Donanımsal Saat
    input  wire       rst_n     // Donanımsal Reset
);

    // Boşta kalan pinleri güvenliğe alıyoruz (Fabrika linter hatasını önler)
    wire _unused = &{ena, ui_in[7:3], uio_in, 1'b0};

    wire start_btn = ui_in[0];
    wire [1:0] neuron_sel = ui_in[2:1];

    // FSM Durumları
    localparam STATE_IDLE    = 2'd0;
    localparam STATE_COMPUTE = 2'd1;
    localparam STATE_DONE    = 2'd2;

    reg [1:0] current_state;
    reg [1:0] step_counter;
    reg       done_reg;

    // 4 Çekirdeğin Akümülatörleri ve ReLU Yazmaçları (Verilog-2001 Uyumlu)
    reg signed [31:0] acc0, acc1, acc2, acc3;
    reg signed [31:0] relu0, relu1, relu2, relu3;

    // Bacak Bağlantıları
    assign uio_oe  = 8'b0000_0001; // Sadece 0. pin DONE çıkışı
    assign uio_out = {7'b0, done_reg};

    // Çıkış Nöronunu Seçen Çoklayıcı (Multiplexer)
    reg [7:0] uo_out_reg;
    always @(*) begin
        case (neuron_sel)
            2'b00: uo_out_reg = relu0[7:0]; // Nöron 0 -> 0
            2'b01: uo_out_reg = relu1[7:0]; // Nöron 1 -> 69 (PyTorch Eşleşmesi!)
            2'b10: uo_out_reg = relu2[7:0]; // Nöron 2 -> 54
            2'b11: uo_out_reg = relu3[7:0]; // Nöron 3 -> 0
        endcase
    end
    assign uo_out = uo_out_reg;

    // PyTorch Ağırlıkları (Her Adım İçin Ayrı Baytlar)
    reg [7:0] w0_byte, w1_byte, w2_byte, w3_byte;
    always @(*) begin
        case (step_counter)
            2'd0: begin
                w0_byte = 8'b10_01_01_01;
                w1_byte = 8'b01_10_10_10;
                w2_byte = 8'b01_01_01_01;
                w3_byte = 8'b10_01_10_01;
            end
            2'd1: begin
                w0_byte = 8'b10_00_10_01;
                w1_byte = 8'b01_10_00_01;
                w2_byte = 8'b01_00_00_00;
                w3_byte = 8'b10_10_01_10;
            end
            2'd2: begin
                w0_byte = 8'b10_10_01_10;
                w1_byte = 8'b01_01_01_10;
                w2_byte = 8'b01_00_10_10;
                w3_byte = 8'b10_10_01_10;
            end
            default: begin
                w0_byte = 8'h00;
                w1_byte = 8'h00;
                w2_byte = 8'h00;
                w3_byte = 8'h00;
            end
        endcase
    end

    // Girdilerimiz
    reg signed [7:0] x0, x1, x2, x3;
    always @(*) begin
        case (step_counter)
            2'd0: begin x0 = 8'sd10; x1 = -8'sd5; x2 = 8'sd20; x3 = 8'sd4; end
            2'd1: begin x0 = 8'sd30; x1 = 8'sd2;  x2 = -8'sd10; x3 = 8'sd50; end
            2'd2: begin x0 = 8'sd15; x1 = 8'sd10; x2 = 8'sd5;  x3 = 8'sd0;  end
            default: begin x0 = 8'sd0; x1 = 8'sd0; x2 = 8'sd0; x3 = 8'sd0; end
        endcase
    end

    // Trit Fonksiyonu
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

    // 4 Çekirdeğin Kısmi Toplamları
    wire signed [15:0] psum0 = compute_trit(x0, w0_byte[1:0]) + compute_trit(x1, w0_byte[3:2]) +
                               compute_trit(x2, w0_byte[5:4]) + compute_trit(x3, w0_byte[7:6]);

    wire signed [15:0] psum1 = compute_trit(x0, w1_byte[1:0]) + compute_trit(x1, w1_byte[3:2]) +
                               compute_trit(x2, w1_byte[5:4]) + compute_trit(x3, w1_byte[7:6]);

    wire signed [15:0] psum2 = compute_trit(x0, w2_byte[1:0]) + compute_trit(x1, w2_byte[3:2]) +
                               compute_trit(x2, w2_byte[5:4]) + compute_trit(x3, w2_byte[7:6]);

    wire signed [15:0] psum3 = compute_trit(x0, w3_byte[1:0]) + compute_trit(x1, w3_byte[3:2]) +
                               compute_trit(x2, w3_byte[5:4]) + compute_trit(x3, w3_byte[7:6]);

    // FSM ve Akümülatör Yazmaçları
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
            step_counter  <= 2'd0;
            done_reg      <= 1'b0;
            acc0 <= 32'sd0; acc1 <= 32'sd0; acc2 <= 32'sd0; acc3 <= 32'sd0;
            relu0 <= 32'sd0; relu1 <= 32'sd0; relu2 <= 32'sd0; relu3 <= 32'sd0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    done_reg     <= 1'b0;
                    step_counter <= 2'd0;
                    acc0 <= 32'sd0; acc1 <= 32'sd0; acc2 <= 32'sd0; acc3 <= 32'sd0;
                    if (start_btn)
                        current_state <= STATE_COMPUTE;
                end

                STATE_COMPUTE: begin
                    acc0 <= acc0 + {{16{psum0[15]}}, psum0};
                    acc1 <= acc1 + {{16{psum1[15]}}, psum1};
                    acc2 <= acc2 + {{16{psum2[15]}}, psum2};
                    acc3 <= acc3 + {{16{psum3[15]}}, psum3};

                    if (step_counter == 2'd2)
                        current_state <= STATE_DONE;
                    else
                        step_counter <= step_counter + 2'd1;
                end

                STATE_DONE: begin
                    done_reg <= 1'b1;
                    // Donanımsal ReLU
                    relu0 <= (acc0[31] == 1'b1) ? 32'sd0 : acc0;
                    relu1 <= (acc1[31] == 1'b1) ? 32'sd0 : acc1;
                    relu2 <= (acc2[31] == 1'b1) ? 32'sd0 : acc2;
                    relu3 <= (acc3[31] == 1'b1) ? 32'sd0 : acc3;

                    if (!start_btn)
                        current_state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
