`timescale 1ps/1ps
`include "dino_states.vh" // Não esqueça de incluir o dicionário de estados aqui também!

module draw (
    input clk,                 // NOVO: Adicionado o clock para podermos usar a memória interna (BSRAM)
    input [7:0] x_cnt,
    input [7:0] y_cnt,
    input [7:0] dino_y,
    input [2:0] dino_state,
    
    input signed [8:0] obs_x,
    input [1:0] obs_type,
    input [7:0] obs_y,
    input [5:0] horizon_offset,
    input signed [8:0] cloud_x,
    
    output collision_pixel,
    output [15:0] pixel_color
);

    // Constantes visuais do sprite
    localparam DINO_X = 0;
    localparam DINO_WIDTH = 64;
    localparam DINO_HEIGHT = 40;
    localparam FLOOR_Y = 97;

    // Cria a memória e carrega o arquivo TXT
    reg [(DINO_WIDTH - 1):0] dino_rom [(DINO_HEIGHT - 1):0]; // standard(jump)
    reg [(DINO_WIDTH - 1):0] dino_r [(DINO_HEIGHT - 1):0]; // right foot up
    reg [(DINO_WIDTH - 1):0] dino_l [(DINO_HEIGHT - 1):0]; // left foot up
    reg [(DINO_WIDTH - 1):0] dino_d [(DINO_HEIGHT - 1):0]; // dead
    reg [(DINO_WIDTH - 1):0] dino_duck_r [(DINO_HEIGHT - 1):0]; // ducking(abaixando) right foot up
    reg [(DINO_WIDTH - 1):0] dino_duck_l [(DINO_HEIGHT - 1):0]; // ducking(abaixando) left foot up

    // Cria as memórias para os novos elementos
    reg [63:0] cactus_rom [39:0];
    reg [63:0] cactus_triple_rom [39:0];
    reg [63:0] pterodactyl_rom [39:0];
    reg [63:0] cloud_rom [39:0];
    reg [63:0] horizon_rom [39:0];

    initial begin
        $readmemb("assets/texturas/dino.txt", dino_rom);
        $readmemb("assets/texturas/dino-r.txt", dino_r);
        $readmemb("assets/texturas/dino-l.txt", dino_l);
        $readmemb("assets/texturas/dino-d.txt", dino_d);
        $readmemb("assets/texturas/dino-d-r.txt", dino_duck_r);
        $readmemb("assets/texturas/dino-d-l.txt", dino_duck_l);
        
        $readmemb("assets/texturas/cactus.txt", cactus_rom);
        $readmemb("assets/texturas/cactus-triple.txt", cactus_triple_rom);
        $readmemb("assets/texturas/pterodactyl.txt", pterodactyl_rom);
        $readmemb("assets/texturas/cloud.txt", cloud_rom);
        $readmemb("assets/texturas/horizon.txt", horizon_rom);
    end

    // ---------------------------------------------------------------------
    // 1. DETERMINAÇÃO DE BOXES E COORDENADAS
    // ---------------------------------------------------------------------
    wire signed [8:0] s_x_cnt = {1'b0, x_cnt};

    // O laser está dentro do quadrado do Dino?
    wire is_inside_dino_box = (x_cnt >= DINO_X) && (x_cnt < DINO_X + DINO_WIDTH) &&
                              (y_cnt >= dino_y) && (y_cnt < dino_y + DINO_HEIGHT);
    wire [5:0] rom_y_index = y_cnt - dino_y; 
    wire [5:0] rom_x_index = x_cnt - DINO_X; 

    // O laser está dentro do quadrado do Obstáculo?
    wire is_inside_obs_box = (s_x_cnt >= obs_x) && (s_x_cnt < obs_x + 64) &&
                             (y_cnt >= obs_y) && (y_cnt < obs_y + 40);
    wire [5:0] obs_rom_y_index = y_cnt - obs_y;
    wire [5:0] obs_rom_x_index = x_cnt - obs_x[7:0];

    // O laser está dentro da Nuvem? (Altura fixa Y = 20)
    wire is_inside_cloud_box = (s_x_cnt >= cloud_x) && (s_x_cnt < cloud_x + 64) &&
                               (y_cnt >= 20) && (y_cnt < 60);
    wire [5:0] cloud_rom_y_index = y_cnt - 20;
    wire [5:0] cloud_rom_x_index = x_cnt - cloud_x[7:0];

    // O laser está dentro do Chão? (Altura fixa Y = FLOOR_Y)
    wire is_inside_horizon_box = (y_cnt >= FLOOR_Y) && (y_cnt < FLOOR_Y + 40);
    wire [5:0] horizon_rom_y_index = y_cnt - FLOOR_Y;
    wire [5:0] horizon_rom_x_index = x_cnt[5:0] + horizon_offset;

    // ---------------------------------------------------------------------
    // 2. LEITURA SINCRONIZADA DAS MEMÓRIAS (BSRAM friendly)
    // ---------------------------------------------------------------------
    reg [(DINO_WIDTH - 1):0] row_stand;
    reg [(DINO_WIDTH - 1):0] row_r;
    reg [(DINO_WIDTH - 1):0] row_l;
    reg [(DINO_WIDTH - 1):0] row_d;
    reg [(DINO_WIDTH - 1):0] row_duck_r;
    reg [(DINO_WIDTH - 1):0] row_duck_l;

    reg [63:0] row_cactus;
    reg [63:0] row_cactus_triple;
    reg [63:0] row_pterodactyl;
    reg [63:0] row_cloud;
    reg [63:0] row_horizon;

    always @(posedge clk) begin
        // Leituras do Dino
        row_stand  <= dino_rom[rom_y_index];
        row_l      <= dino_l[rom_y_index];
        row_r      <= dino_r[rom_y_index];
        row_duck_l <= dino_duck_l[rom_y_index];
        row_duck_r <= dino_duck_r[rom_y_index];
        row_d      <= dino_d[rom_y_index];

        // Leituras dos Elementos adicionais
        row_cactus        <= cactus_rom[obs_rom_y_index];
        row_cactus_triple <= cactus_triple_rom[obs_rom_y_index];
        row_pterodactyl   <= pterodactyl_rom[obs_rom_y_index];
        row_cloud         <= cloud_rom[cloud_rom_y_index];
        row_horizon       <= horizon_rom[horizon_rom_y_index];
    end

    // ---------------------------------------------------------------------
    // 3. SELEÇÃO DE PIXELS
    // ---------------------------------------------------------------------
    
    // Mux Dino
    wire [(DINO_WIDTH - 1):0] current_rom_row = 
        (dino_state == `STATE_STAND)  ? row_stand :
        (dino_state == `STATE_RUN_L)  ? row_l :
        (dino_state == `STATE_RUN_R)  ? row_r :
        (dino_state == `STATE_DUCK_L) ? row_duck_l :
        (dino_state == `STATE_DUCK_R) ? row_duck_r :
                                        row_d;
    wire dino_pixel_is_solid = current_rom_row[(DINO_WIDTH - 1) - rom_x_index];
    wire dino_pixel_visible  = is_inside_dino_box && dino_pixel_is_solid;

    // Mux Obstáculo
    wire [63:0] current_obs_row = 
        (obs_type == 2'd0) ? row_cactus :
        (obs_type == 2'd1) ? row_cactus_triple :
                             row_pterodactyl;
    wire obs_pixel_is_solid = current_obs_row[63 - obs_rom_x_index];
    wire obs_pixel_visible  = is_inside_obs_box && obs_pixel_is_solid;

    // Nuvem
    wire cloud_pixel_is_solid = row_cloud[63 - cloud_rom_x_index];
    wire cloud_pixel_visible  = is_inside_cloud_box && cloud_pixel_is_solid;

    // Chão
    wire horizon_pixel_is_solid = row_horizon[63 - horizon_rom_x_index];
    wire horizon_pixel_visible  = is_inside_horizon_box && horizon_pixel_is_solid;

    // ---------------------------------------------------------------------
    // 4. SAÍDA DE COR E DETECÇÃO DE COLISÃO
    // ---------------------------------------------------------------------
    
    // Colisão pixel-perfect: se os pixels do Dino e do Obstáculo são ambos sólidos
    assign collision_pixel = dino_pixel_visible && obs_pixel_visible;

    // Cor final: pinta pixel como branco (FFFF) se qualquer elemento for sólido
    assign pixel_color = (dino_pixel_visible || obs_pixel_visible || horizon_pixel_visible || cloud_pixel_visible) ? 16'hFFFF : 16'h0000;

endmodule