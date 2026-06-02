`timescale 1ps/1ps
`include "dino_states.vh" // Não esqueça de incluir o dicionário de estados aqui também!

module draw (
    input clk,                 // NOVO: Adicionado o clock para podermos usar a memória interna (BSRAM)
    input [7:0] x_cnt,
    input [7:0] y_cnt,
    input [7:0] dino_y,
    input [2:0] dino_state,
    
    output [15:0] pixel_color
);

    // Constantes visuais do sprite
    localparam DINO_X = 0;
    localparam DINO_WIDTH = 64;
    localparam DINO_HEIGHT = 40;

    // Cria a memória e carrega o arquivo TXT
    reg [(DINO_WIDTH - 1):0] dino_rom [(DINO_HEIGHT - 1):0]; // standard(jump)
    reg [(DINO_WIDTH - 1):0] dino_r [(DINO_HEIGHT - 1):0]; // right foot up
    reg [(DINO_WIDTH - 1):0] dino_l [(DINO_HEIGHT - 1):0]; // left foot up
    reg [(DINO_WIDTH - 1):0] dino_d [(DINO_HEIGHT - 1):0]; // dead
    reg [(DINO_WIDTH - 1):0] dino_duck_r [(DINO_HEIGHT - 1):0]; // ducking(abaixando) right foot up
    reg [(DINO_WIDTH - 1):0] dino_duck_l [(DINO_HEIGHT - 1):0]; // ducking(abaixando) left foot up

    initial begin
        $readmemb("dino.txt", dino_rom);
        $readmemb("dino-r.txt", dino_r);
        $readmemb("dino-l.txt", dino_l);
        $readmemb("dino-d.txt", dino_d);
        $readmemb("dino-d-r.txt", dino_duck_r);
        $readmemb("dino-d-l.txt", dino_duck_l);
    end

    // 1. O laser está dentro do quadrado do Dino?
    wire is_inside_dino_box = (x_cnt >= DINO_X) && (x_cnt < DINO_X + DINO_WIDTH) &&
                              (y_cnt >= dino_y) && (y_cnt < dino_y + DINO_HEIGHT);

    // 2. Coordenadas da ROM
    wire [5:0] rom_y_index = y_cnt - dino_y; 
    wire [5:0] rom_x_index = x_cnt - DINO_X; 

    // =====================================================================
    // 3A. LEITURA SINCRONIZADA (O salvador das LUTs)
    // Registradores intermediários para guardar as linhas lidas da memória
    // =====================================================================
    reg [(DINO_WIDTH - 1):0] row_stand;
    reg [(DINO_WIDTH - 1):0] row_r;
    reg [(DINO_WIDTH - 1):0] row_l;
    reg [(DINO_WIDTH - 1):0] row_d;
    reg [(DINO_WIDTH - 1):0] row_duck_r;
    reg [(DINO_WIDTH - 1):0] row_duck_l;

    always @(posedge clk) begin
        row_stand  <= dino_rom[rom_y_index];
        row_l      <= dino_l[rom_y_index];
        row_r      <= dino_r[rom_y_index];
        row_duck_l <= dino_duck_l[rom_y_index];
        row_duck_r <= dino_duck_r[rom_y_index];
        row_d      <= dino_d[rom_y_index];
    end

    // =====================================================================
    // 3B. MULTIPLEXADOR (Escolhe a linha correta baseada no estado atual)
    // =====================================================================
    wire [(DINO_WIDTH - 1):0] current_rom_row = 
        (dino_state == `STATE_STAND)  ? row_stand :
        (dino_state == `STATE_RUN_L)  ? row_l :
        (dino_state == `STATE_RUN_R)  ? row_r :
        (dino_state == `STATE_DUCK_L) ? row_duck_l :
        (dino_state == `STATE_DUCK_R) ? row_duck_r :
                                        row_d;

    // 4. Descobre o bit exato (Corrigido DINO_HEIGHT para DINO_WIDTH)
    wire dino_pixel_is_solid = current_rom_row[(DINO_WIDTH - 1) - rom_x_index];

    // 5. Cor final a ser desenhada
    assign pixel_color = (is_inside_dino_box && dino_pixel_is_solid) ? 16'hFFFF : 16'h0000;

endmodule