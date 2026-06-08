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
    // FIOS DE CONEXÃO INTERNA
    // ==========================================
    wire [7:0] w_x_cnt;
    wire [7:0] w_y_cnt;
    wire [7:0] w_dino_y;
    wire [15:0] w_pixel_color;
    wire [2:0] dino_state; // definido em dino_states.vh

    // Fios da pontuação
    wire [3:0] w_score_d0, w_score_d1, w_score_d2, w_score_d3, w_score_d4;
    wire [3:0] w_hi_d0, w_hi_d1, w_hi_d2, w_hi_d3, w_hi_d4;

    wire w_menu_wants_reset;

    // Novos fios para o cenário, obstáculos e colisões
    wire w_collision_pixel;
    wire signed [8:0] w_obs_x;
    wire [1:0] w_obs_type;
    wire [7:0] w_obs_y;
    wire [5:0] w_horizon_offset;
    wire signed [8:0] w_cloud_x;


    // ==========================================
    // DRIVER DA TELA LCD
    // ==========================================
    screen tela (
        .clk(clk),
        .resetn(1'b1),
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
    // ENGINE DO JOGO
    // ==========================================
    game physics (
        .clk(clk),
        .button_jump(button_1),
        .button_duck(button_2),
        .dino_y(w_dino_y),            // Informa a altura atual do Dino
        .menu_reset_out(w_menu_wants_reset),
        .dino_state(dino_state),
        
        .collision_pixel(w_collision_pixel),
        .obs_x(w_obs_x),
        .obs_type(w_obs_type),
        .obs_y(w_obs_y),
        .horizon_offset(w_horizon_offset),
        .cloud_x(w_cloud_x),
        
        .score_d0(w_score_d0), .score_d1(w_score_d1), .score_d2(w_score_d2), .score_d3(w_score_d3), .score_d4(w_score_d4),
        .hi_d0(w_hi_d0), .hi_d1(w_hi_d1), .hi_d2(w_hi_d2), .hi_d3(w_hi_d3), .hi_d4(w_hi_d4)
    );

    // ==========================================
    // GERADOR DE VÍDEO
    // ==========================================
    draw game_draw (
        .clk(clk),
        .x_cnt(w_x_cnt),             // Lê o X atual da tela
        .y_cnt(w_y_cnt),             // Lê o Y atual da tela
        .dino_y(w_dino_y),           // Lê o Y atual do Dino (Física)
        .dino_state(dino_state),     // Lê o estado atual do dino
        .pixel_color(w_pixel_color), // Devolve a cor final para o fio
        
        .obs_x(w_obs_x),
        .obs_type(w_obs_type),
        .obs_y(w_obs_y),
        .horizon_offset(w_horizon_offset),
        .cloud_x(w_cloud_x),
        .collision_pixel(w_collision_pixel),
        
        .score_d0(w_score_d0), .score_d1(w_score_d1), .score_d2(w_score_d2), .score_d3(w_score_d3), .score_d4(w_score_d4),
        .hi_d0(w_hi_d0), .hi_d1(w_hi_d1), .hi_d2(w_hi_d2), .hi_d3(w_hi_d3), .hi_d4(w_hi_d4)
    );

endmodule