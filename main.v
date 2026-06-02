`timescale 1ps/1ps

module main(
    input clk,          // Clock de 27MHz
    input button_1,  // Botão S1 (Pino 3)
    input button_2,   // Botão S2 (Pino 4)

    output ser_tx,      // Não usado por enquanto
    input ser_rx,       // Não usado por enquanto

    output lcd_resetn,
    output lcd_clk,
    output lcd_cs,
    output lcd_rs,
    output lcd_data
);

    // ==========================================
    // FIOS DE CONEXÃO INTERNA (O "Placa-Mãe")
    // ==========================================
    wire [7:0] w_x_cnt;
    wire [7:0] w_y_cnt;
    wire [7:0] w_dino_y;
    wire [15:0] w_pixel_color;
    wire [2:0] dino_state; // definido em dino_states.vh

    wire w_menu_wants_reset;
    wire w_screen_resetn = ~w_menu_wants_reset;


    // ==========================================
    // 1. MOTOR DE TELA (LCD Driver)
    // ==========================================
    screen tela (
        .clk(clk),
        .resetn(w_screen_resetn),
        .pixel_color(w_pixel_color), // Lê a cor que o game_draw calculou
        .x_cnt(w_x_cnt),             // Informa qual X está desenhando
        .y_cnt(w_y_cnt),             // Informa qual Y está desenhando
        
        // Pinos físicos do LCD
        .lcd_resetn(lcd_resetn),
        .lcd_clk(lcd_clk),
        .lcd_cs(lcd_cs),
        .lcd_rs(lcd_rs),
        .lcd_data(lcd_data)
    );

    // ==========================================
    // 2. FÍSICA DO JOGO (Game Engine)
    // ==========================================
    game physics (
        .clk(clk),
        .button_jump(button_1),
        .button_duck(button_2),
        .dino_y(w_dino_y),            // Informa a altura atual do Dino
        .menu_reset_out(w_menu_wants_reset),
        .dino_state(dino_state)
    );

    // ==========================================
    // 3. GERADOR DE VÍDEO (Placa de Vídeo)
    // ==========================================
    draw game_draw (
        .clk(clk),
        .x_cnt(w_x_cnt),             // Lê o X atual da tela
        .y_cnt(w_y_cnt),             // Lê o Y atual da tela
        .dino_y(w_dino_y),           // Lê o Y atual do Dino (Física)
        .dino_state(dino_state),     // Lê o estado atual do dino
        .pixel_color(w_pixel_color)  // Devolve a cor final para o fio
    );

endmodule