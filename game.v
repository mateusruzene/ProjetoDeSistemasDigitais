`timescale 1ps/1ps
`include "dino_states.vh"
`include "obs.vh"

module game (
    input clk,
    input button_jump,
    input button_duck,
    
    input collision_pixel,
    
    output reg [7:0] dino_y = 97, // Já inicia no chão
    output reg menu_reset_out = 0,
    output reg [2:0] dino_state = `STATE_STAND,
    
    output reg signed [8:0] obs_x = 240,
    output reg [1:0] obs_type = 0, // 0 = cactus, 1 = cactus-triple, 2 = pterodactyl
    output reg [7:0] obs_y = 97,
    output reg [5:0] horizon_offset = 0,
    output reg signed [8:0] cloud_x = 240,

    // Pontuações BCD
    output reg [3:0] score_d0 = 0,
    output reg [3:0] score_d1 = 0,
    output reg [3:0] score_d2 = 0,
    output reg [3:0] score_d3 = 0,
    output reg [3:0] score_d4 = 0,
    output reg [3:0] hi_d0 = 0,
    output reg [3:0] hi_d1 = 0,
    output reg [3:0] hi_d2 = 0,
    output reg [3:0] hi_d3 = 0,
    output reg [3:0] hi_d4 = 0
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
    reg [2:0] score_frame_cnt = 0; // Contador de frames para pontuação
    
    // Filtros de ruído para os dois botões
    reg jump_r1=1, jump_r2=1;
    reg duck_r1=1, duck_r2=1;

    // Gerador de número pseudo-aleatório
    reg [7:0] rand_reg = 0;
    reg collision_latched = 0;
    reg [1:0] cloud_div = 0;

    always @(posedge clk) begin
        // Atualiza o registrador aleatório continuamente
        rand_reg <= rand_reg + 1;

        // Sincronizando os botões
        jump_r1 <= button_jump; jump_r2 <= jump_r1;
        duck_r1 <= button_duck; duck_r2 <= duck_r1;

        // Latch de colisão pixel-perfect
        if (collision_pixel && dino_state != `STATE_DEAD) begin
            collision_latched <= 1;
        end

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
                    
                    // Reseta o cenário e obstáculos
                    obs_x <= 240;
                    obs_type <= 0;
                    obs_y <= 97;
                    cloud_x <= 240;
                    horizon_offset <= 0;
                    collision_latched <= 0;

                    // Reseta score atual
                    score_d0 <= 0;
                    score_d1 <= 0;
                    score_d2 <= 0;
                    score_d3 <= 0;
                    score_d4 <= 0;
                end else begin
                    menu_reset_out <= 1'b0;
                end

            end else begin
                // SE ESTIVER VIVO:
                menu_reset_out <= 1'b0;

                // A) Verifica colisão pendente
                if (collision_latched) begin
                    dino_state <= `STATE_DEAD;
                    dino_vel <= 0;
                    // Atualiza high score se a pontuação atual for maior
                    if ({score_d4, score_d3, score_d2, score_d1, score_d0} > {hi_d4, hi_d3, hi_d2, hi_d1, hi_d0}) begin
                        hi_d4 <= score_d4;
                        hi_d3 <= score_d3;
                        hi_d2 <= score_d2;
                        hi_d1 <= score_d1;
                        hi_d0 <= score_d0;
                    end
                end else begin
                    // B) Movimentação do Dino (Física)
                    // Está no chão?
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
                    
                    // Está no ar!
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

                    // C) Atualiza o cenário e obstáculos (Scrolling)
                    
                    // Nuvem (move 1px a cada 4 frames)
                    if (cloud_div == 3) begin
                        cloud_div <= 0;
                        if (cloud_x <= -9'sd64) begin
                            cloud_x <= 240;
                        end else begin
                            cloud_x <= cloud_x - 1;
                        end
                    end else begin
                        cloud_div <= cloud_div + 1;
                    end

                    // Chão (move 2px por frame)
                    horizon_offset <= horizon_offset + 2;

                    // Obstáculos (move 3px por frame)
                    if (obs_x <= -9'sd64) begin
                        obs_x <= 240;
                        // Escolhe novo obstáculo aleatório usando o contador
                        if (rand_reg[1:0] == 2'd0) begin
                            obs_type <= `STATE_CACTUS; // Cactus
                            obs_y <= 97;
                        end else if (rand_reg[1:0] == 2'd1) begin
                            obs_type <= `STATE_TRIPLE_CACTUS; // Cactus Triple
                            obs_y <= 97;
                        end else if (rand_reg[1:0] == 2'd2) begin
                            obs_type <= `STATE_PTERODACTYL_D; // Pterodactyl alto
                            obs_y <= 78;
                        end else begin
                            obs_type <= `STATE_PTERODACTYL_D; // Pterodactyl baixo
                            obs_y <= 95;
                        end
                    end else begin
                        if(obs_type == `STATE_PTERODACTYL_D) begin
                            obs_type <= leg_toggle ? `STATE_PTERODACTYL_T : `STATE_PTERODACTYL_D;
                            obs_x <= obs_x - 4;
                        end else if(obs_type == `STATE_PTERODACTYL_T) begin
                            obs_type <= leg_toggle ? `STATE_PTERODACTYL_D : `STATE_PTERODACTYL_T;
                            obs_x <= obs_x - 4;
                        end else begin
                            obs_x <= obs_x - 3;
                        end
                    end

                    // Incremento de Pontuação BCD a cada 6 frames
                    if (score_frame_cnt == 5) begin
                        score_frame_cnt <= 0;
                        if (score_d0 == 9) begin
                            score_d0 <= 0;
                            if (score_d1 == 9) begin
                                score_d1 <= 0;
                                if (score_d2 == 9) begin
                                    score_d2 <= 0;
                                    if (score_d3 == 9) begin
                                        score_d3 <= 0;
                                        if (score_d4 == 9) begin
                                            score_d4 <= 0;
                                        end else begin
                                            score_d4 <= score_d4 + 1;
                                        end
                                    end else begin
                                        score_d3 <= score_d3 + 1;
                                    end
                                end else begin
                                    score_d2 <= score_d2 + 1;
                                end
                            end else begin
                                score_d1 <= score_d1 + 1;
                            end
                        end else begin
                            score_d0 <= score_d0 + 1;
                        end
                    end else begin
                        score_frame_cnt <= score_frame_cnt + 1;
                    end
                end
            end
                
        end else begin
            game_tick_cnt <= game_tick_cnt + 1;
        end
    end

endmodule