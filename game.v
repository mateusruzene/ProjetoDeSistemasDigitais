`timescale 1ps/1ps
`include "dino_states.vh"

module game (
    input clk,
    input button_jump,
    input button_duck,
    
    output reg [7:0] dino_y = 97, // Já inicia no chão
    output reg menu_reset_out = 0,
    output reg [2:0] dino_state = `STATE_STAND
);

    localparam FLOOR_Y = 97;
    localparam GRAVITY = 1;
    localparam FAST_FALL_GRAVITY = 4; // Gravidade extra pesada para quando abaixar no ar
    localparam JUMP_FORCE = -11;

    reg signed [7:0] dino_vel = 0;
    
    // Contadores de tempo
    reg [18:0] game_tick_cnt = 0;
    reg [3:0] anim_tick_cnt = 0; // Metrônomo para as perninhas
    reg leg_toggle = 0;          // 0 = Perna Esquerda, 1 = Perna Direita
    
    // Filtros de ruído para os dois botões
    reg jump_r1=1, jump_r2=1;
    reg duck_r1=1, duck_r2=1;

    always @(posedge clk) begin
        // Sincronizando os botões
        jump_r1 <= button_jump; jump_r2 <= jump_r1;
        duck_r1 <= button_duck; duck_r2 <= duck_r1;

        // Relógio do jogo (60 Hz / 60 FPS)
        if (game_tick_cnt == 450000) begin
            game_tick_cnt <= 0;
            
            // -----------------------------------------------------
            // 1. ATUALIZA O METRÔNOMO DE ANIMAÇÃO
            // -----------------------------------------------------
            // A cada 6 frames (~10 vezes por segundo), troca a perna
            if (anim_tick_cnt == 6) begin
                anim_tick_cnt <= 0;
                leg_toggle <= ~leg_toggle; 
            end else begin
                anim_tick_cnt <= anim_tick_cnt + 1;
            end

            // -----------------------------------------------------
            // 2. MÁQUINA DE ESTADOS E FÍSICA UNIDAS
            // -----------------------------------------------------
            if (dino_state == `STATE_DEAD) begin
                // SE ESTIVER MORTO: Trava tudo. Espera o botão para resetar.
                dino_vel <= 0;
                if (jump_r2 == 1'b0) begin 
                    menu_reset_out <= 1'b1; // Manda apagar a tela
                    dino_y <= FLOOR_Y;      // Ressuscita o Dino
                    dino_state <= `STATE_STAND;
                end else begin
                    menu_reset_out <= 1'b0;
                end

            end else begin
                // SE ESTIVER VIVO:
                menu_reset_out <= 1'b0;

                // A) Está no chão?
                if (dino_y == FLOOR_Y) begin
                    if ((jump_r2 == 1'b0) && (duck_r2 == 1'b1)) begin 
                        // Pula
                        dino_vel <= JUMP_FORCE;
                        dino_y <= FLOOR_Y + JUMP_FORCE; 
                        dino_state <= `STATE_STAND;
                        
                    end else if (duck_r2 == 1'b0) begin 
                        // Abaixado no chão
                        dino_vel <= 0;
                        dino_state <= (leg_toggle) ? `STATE_DUCK_R : `STATE_DUCK_L;
                        
                    end else begin 
                        // Correndo no chão
                        dino_vel <= 0;
                        dino_state <= (leg_toggle) ? `STATE_RUN_R : `STATE_RUN_L;
                    end
                end 
                
                // B) Está no ar!
                else begin
                    if (duck_r2 == 1'b0) begin
                        // FAST FALL (Abaixou no ar)
                        dino_vel <= dino_vel + FAST_FALL_GRAVITY; 
                        dino_state <= `STATE_DUCK_L; // Usa uma das sprites de abaixar para cair
                    end else begin
                        // Pulo Normal
                        dino_vel <= dino_vel + GRAVITY;
                        dino_state <= `STATE_STAND;  // Pose padrão de pulo
                    end
                    
                    dino_y <= dino_y + dino_vel;     
                 
                    // Previsão de colisão com o chão
                    if ($signed(dino_y + dino_vel) >= FLOOR_Y) begin
                        dino_y <= FLOOR_Y;
                        dino_vel <= 0;
                    end
                end
            end
                
        end else begin
            game_tick_cnt <= game_tick_cnt + 1;
        end
    end

endmodule