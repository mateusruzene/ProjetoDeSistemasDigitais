`timescale 1ps/1ps
`include "dino_states.vh"
`include "obs.vh"

module draw (
    input clk,
    input [7:0] x_cnt,
    input [7:0] y_cnt,
    input [7:0] dino_y,
    input [2:0] dino_state,
    
    input signed [8:0] obs_x,
    input [1:0] obs_type,
    input [7:0] obs_y,
    input [5:0] horizon_offset,
    input signed [8:0] cloud_x,
    
    // Pontuações BCD
    input [3:0] score_d0,
    input [3:0] score_d1,
    input [3:0] score_d2,
    input [3:0] score_d3,
    input [3:0] score_d4,
    input [3:0] hi_d0,
    input [3:0] hi_d1,
    input [3:0] hi_d2,
    input [3:0] hi_d3,
    input [3:0] hi_d4,
    
    output collision_pixel,
    output [15:0] pixel_color
);

    // Constantes visuais do sprite
    localparam DINO_X = 0;
    localparam DINO_WIDTH = 64;
    localparam DINO_HEIGHT = 40;
    localparam FLOOR_Y = 97;

    // Game Over 
    localparam GAMEOVER_X = 80;
    localparam GAMEOVER_Y = 20;
    localparam GAMEOVER_W = 64;
    localparam GAMEOVER_H = 40;

    // Memórias dos sprites existentes
    reg [(DINO_WIDTH - 1):0] dino_rom [(DINO_HEIGHT - 1):0];
    reg [(DINO_WIDTH - 1):0] dino_r [(DINO_HEIGHT - 1):0];
    reg [(DINO_WIDTH - 1):0] dino_l [(DINO_HEIGHT - 1):0];
    reg [(DINO_WIDTH - 1):0] dino_d [(DINO_HEIGHT - 1):0];
    reg [(DINO_WIDTH - 1):0] dino_duck_r [(DINO_HEIGHT - 1):0];
    reg [(DINO_WIDTH - 1):0] dino_duck_l [(DINO_HEIGHT - 1):0];

    reg [63:0] cactus_rom [39:0];
    reg [63:0] cactus_triple_rom [39:0];
    reg [63:0] pterodactyl_t_rom [39:0];
    reg [63:0] pterodactyl_d_rom [39:0];
    reg [63:0] cloud_rom [39:0];
    reg [63:0] horizon_rom [39:0];

    //Game Over
    reg [63:0] gameover_rom [39:0];

    initial begin
        $readmemb("assets/texturas/dino.txt", dino_rom);
        $readmemb("assets/texturas/dino-r.txt", dino_r);
        $readmemb("assets/texturas/dino-l.txt", dino_l);
        $readmemb("assets/texturas/dino-d.txt", dino_d);
        $readmemb("assets/texturas/dino-d-r.txt", dino_duck_r);
        $readmemb("assets/texturas/dino-d-l.txt", dino_duck_l);
        
        $readmemb("assets/texturas/cactus.txt", cactus_rom);
        $readmemb("assets/texturas/cactus-triple.txt", cactus_triple_rom);
        $readmemb("assets/texturas/pterodactyl-t.txt", pterodactyl_t_rom);
        $readmemb("assets/texturas/pterodactyl-d.txt", pterodactyl_d_rom);
        $readmemb("assets/texturas/cloud.txt", cloud_rom);
        $readmemb("assets/texturas/horizon.txt", horizon_rom);
        
        // Game Over
        $readmemb("assets/texturas/restart.txt", gameover_rom);
    end

    // ---------------------------------------------------------------------
    // DETERMINAÇÃO DE BOXES E COORDENADAS
    // ---------------------------------------------------------------------
    wire signed [8:0] s_x_cnt = {1'b0, x_cnt};

    // Dino
    wire is_inside_dino_box = (x_cnt >= DINO_X) && (x_cnt < DINO_X + DINO_WIDTH) &&
                              (y_cnt >= dino_y) && (y_cnt < dino_y + DINO_HEIGHT);
    wire [5:0] rom_y_index = y_cnt - dino_y; 
    wire [5:0] rom_x_index = x_cnt - DINO_X; 

    // Obstáculo
    wire is_inside_obs_box = (s_x_cnt >= obs_x) && (s_x_cnt < obs_x + 64) &&
                             (y_cnt >= obs_y) && (y_cnt < obs_y + 40);
    wire [5:0] obs_rom_y_index = y_cnt - obs_y;
    wire [5:0] obs_rom_x_index = x_cnt - obs_x[7:0];

    // Nuvem
    wire is_inside_cloud_box = (s_x_cnt >= cloud_x) && (s_x_cnt < cloud_x + 64) &&
                               (y_cnt >= 20) && (y_cnt < 60);
    wire [5:0] cloud_rom_y_index = y_cnt - 20;
    wire [5:0] cloud_rom_x_index = x_cnt - cloud_x[7:0];

    // Chão
    wire is_inside_horizon_box = (y_cnt >= FLOOR_Y) && (y_cnt < FLOOR_Y + 40);
    wire [5:0] horizon_rom_y_index = y_cnt - FLOOR_Y;
    wire [5:0] horizon_rom_x_index = x_cnt[5:0] + horizon_offset;

    // Game Over
    wire inside_gameover = (dino_state == `STATE_DEAD) &&
                           (x_cnt >= GAMEOVER_X) && (x_cnt < GAMEOVER_X + GAMEOVER_W) &&
                           (y_cnt >= GAMEOVER_Y) && (y_cnt < GAMEOVER_Y + GAMEOVER_H);
    wire [5:0] gameover_rom_y_index = y_cnt - GAMEOVER_Y;
    wire [5:0] gameover_rom_x_index = x_cnt - GAMEOVER_X;

    // ---------------------------------------------------------------------
    // LEITURA SINCRONIZADA DAS MEMÓRIAS (COM ÍNDICE SEGURO)
    // ---------------------------------------------------------------------
    reg [(DINO_WIDTH - 1):0] current_dino_row;
    reg [63:0] current_obs_row;

    reg [63:0] row_cloud;
    reg [63:0] row_horizon;
    reg [63:0] row_gameover;

    wire [5:0] safe_gameover_y = inside_gameover ? gameover_rom_y_index : 6'b0;

    always @(posedge clk) begin
        // MUX de leitura do Dino
        case (dino_state)
            `STATE_STAND:  current_dino_row <= dino_rom[rom_y_index];
            `STATE_RUN_L:  current_dino_row <= dino_l[rom_y_index];
            `STATE_RUN_R:  current_dino_row <= dino_r[rom_y_index];
            `STATE_DUCK_L: current_dino_row <= dino_duck_l[rom_y_index];
            `STATE_DUCK_R: current_dino_row <= dino_duck_r[rom_y_index];
            default:       current_dino_row <= dino_d[rom_y_index]; // STATE_DEAD
        endcase

        // MUX de leitura do Obstáculo
        case (obs_type)
            `STATE_CACTUS:        current_obs_row <= cactus_rom[obs_rom_y_index];
            `STATE_TRIPLE_CACTUS: current_obs_row <= cactus_triple_rom[obs_rom_y_index];
            `STATE_PTERODACTYL_D: current_obs_row <= pterodactyl_d_rom[obs_rom_y_index];
            default:              current_obs_row <= pterodactyl_t_rom[obs_rom_y_index]; // STATE_PTERODACTYL_T
        endcase

        // Leituras dos Elementos únicos
        row_cloud    <= cloud_rom[cloud_rom_y_index];
        row_horizon  <= horizon_rom[horizon_rom_y_index];
        row_gameover <= gameover_rom[safe_gameover_y];
    end

    // ---------------------------------------------------------------------
    // SELEÇÃO DE PIXELS
    // ---------------------------------------------------------------------
    
    // Dino
    wire dino_pixel_is_solid = current_dino_row[(DINO_WIDTH - 1) - rom_x_index];
    wire dino_pixel_visible  = is_inside_dino_box && dino_pixel_is_solid;

    // Obstáculo
    wire obs_pixel_is_solid = current_obs_row[63 - obs_rom_x_index];
    wire obs_pixel_visible  = is_inside_obs_box && obs_pixel_is_solid;

    // Nuvem
    wire cloud_pixel_is_solid = row_cloud[63 - cloud_rom_x_index];
    wire cloud_pixel_visible  = is_inside_cloud_box && cloud_pixel_is_solid;

    // Chão
    wire horizon_pixel_is_solid = row_horizon[63 - horizon_rom_x_index];
    wire horizon_pixel_visible  = is_inside_horizon_box && horizon_pixel_is_solid;

    // Game Over
    wire gameover_pixel_solid = row_gameover[63 - gameover_rom_x_index];
    wire gameover_visible = inside_gameover && gameover_pixel_solid;

    // ---------------------------------------------------------------------
    // SAÍDA DE COR E DETECÇÃO DE COLISÃO
    // ---------------------------------------------------------------------
    
    // Colisão pixel-perfect: se os pixels do Dino e do Obstáculo são ambos sólidos
    assign collision_pixel = dino_pixel_visible && obs_pixel_visible;

    // ---------------------------------------------------------------------
    // RENDERIZAÇÃO DE TEXTO
    // ---------------------------------------------------------------------
    wire show_hi = (dino_state == `STATE_DEAD) || (hi_d4 != 0 || hi_d3 != 0 || hi_d2 != 0 || hi_d1 != 0 || hi_d0 != 0);

    reg [3:0] selected_char;
    reg [2:0] cx;
    reg is_inside_char;

    always @(*) begin
        selected_char = 4'd12; // default space
        cx = 3'd0;
        is_inside_char = 0;
        if (y_cnt >= 8'd10 && y_cnt < 8'd17) begin
            if (x_cnt >= 8'd200 && x_cnt < 8'd205) begin
                selected_char = score_d4;
                cx = x_cnt - 8'd200;
                is_inside_char = 1;
            end else if (x_cnt >= 8'd206 && x_cnt < 8'd211) begin
                selected_char = score_d3;
                cx = x_cnt - 8'd206;
                is_inside_char = 1;
            end else if (x_cnt >= 8'd212 && x_cnt < 8'd217) begin
                selected_char = score_d2;
                cx = x_cnt - 8'd212;
                is_inside_char = 1;
            end else if (x_cnt >= 8'd218 && x_cnt < 8'd223) begin
                selected_char = score_d1;
                cx = x_cnt - 8'd218;
                is_inside_char = 1;
            end else if (x_cnt >= 8'd224 && x_cnt < 8'd229) begin
                selected_char = score_d0;
                cx = x_cnt - 8'd224;
                is_inside_char = 1;
            end else if (show_hi) begin
                if (x_cnt >= 8'd140 && x_cnt < 8'd145) begin
                    selected_char = 4'd10; // H
                    cx = x_cnt - 8'd140;
                    is_inside_char = 1;
                end else if (x_cnt >= 8'd146 && x_cnt < 8'd151) begin
                    selected_char = 4'd11; // I
                    cx = x_cnt - 8'd146;
                    is_inside_char = 1;
                end else if (x_cnt >= 8'd156 && x_cnt < 8'd161) begin
                    selected_char = hi_d4;
                    cx = x_cnt - 8'd156;
                    is_inside_char = 1;
                end else if (x_cnt >= 8'd162 && x_cnt < 8'd167) begin
                    selected_char = hi_d3;
                    cx = x_cnt - 8'd162;
                    is_inside_char = 1;
                end else if (x_cnt >= 8'd168 && x_cnt < 8'd173) begin
                    selected_char = hi_d2;
                    cx = x_cnt - 8'd168;
                    is_inside_char = 1;
                end else if (x_cnt >= 8'd174 && x_cnt < 8'd179) begin
                    selected_char = hi_d1;
                    cx = x_cnt - 8'd174;
                    is_inside_char = 1;
                end else if (x_cnt >= 8'd180 && x_cnt < 8'd185) begin
                    selected_char = hi_d0;
                    cx = x_cnt - 8'd180;
                    is_inside_char = 1;
                end
            end
        end
    end

    // Alinhamento de latência (atraso de 1 ciclo para bater com as texturas da ROM)
    reg [3:0] r_selected_char;
    reg [2:0] r_cx;
    reg [2:0] r_cy;
    reg r_is_inside_char;

    always @(posedge clk) begin
        r_selected_char  <= selected_char;
        r_cx             <= cx;
        r_cy             <= y_cnt - 8'd10;
        r_is_inside_char <= is_inside_char;
    end

    reg [34:0] char_pattern;
    always @(*) begin
        case (r_selected_char)
            4'd0:  char_pattern = 35'b11111_10001_10001_10001_10001_10001_11111;
            4'd1:  char_pattern = 35'b00100_01100_00100_00100_00100_00100_01110;
            4'd2:  char_pattern = 35'b11111_00001_00001_11111_10000_10000_11111;
            4'd3:  char_pattern = 35'b11111_00001_00001_11111_00001_00001_11111;
            4'd4:  char_pattern = 35'b10001_10001_10001_11111_00001_00001_00001;
            4'd5:  char_pattern = 35'b11111_10000_10000_11111_00001_00001_11111;
            4'd6:  char_pattern = 35'b11111_10000_10000_11111_10001_10001_11111;
            4'd7:  char_pattern = 35'b11111_00001_00010_00100_01000_01000_01000;
            4'd8:  char_pattern = 35'b11111_10001_10001_11111_10001_10001_11111;
            4'd9:  char_pattern = 35'b11111_10001_10001_11111_00001_00001_11111;
            4'd10: char_pattern = 35'b10001_10001_10001_11111_10001_10001_10001; // H
            4'd11: char_pattern = 35'b11111_00100_00100_00100_00100_00100_11111; // I
            default: char_pattern = 35'b0; // Espaço
        endcase
    end

    wire [5:0] pattern_idx = (r_cy * 5) + r_cx;
    wire char_pixel_is_solid = (pattern_idx < 6'd35) ? char_pattern[6'd34 - pattern_idx] : 1'b0;
    wire char_pixel_visible = r_is_inside_char && char_pixel_is_solid;

     // Cor final: pinta pixel como branco (FFFF) se qualquer elemento for sólido
     assign pixel_color = (gameover_visible || dino_pixel_visible || obs_pixel_visible || horizon_pixel_visible || cloud_pixel_visible || char_pixel_visible) ? 16'hFFFF : 16'h0000;

endmodule