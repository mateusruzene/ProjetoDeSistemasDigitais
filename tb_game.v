`timescale 1ns/1ns
`include "dino_states.vh"

module tb_game;
    reg clk;
    reg button_jump;
    reg button_duck;

    wire [7:0] dino_y;
    wire menu_reset_out;
    wire [2:0] dino_state;
    wire signed [8:0] obs_x;
    wire [1:0] obs_type;
    wire [7:0] obs_y;
    wire [5:0] horizon_offset;
    wire signed [8:0] cloud_x;

    wire collision_pixel;
    wire [15:0] pixel_color;

    reg [7:0] x_cnt;
    reg [7:0] y_cnt;

    // Instanciar a física do jogo
    game physics (
        .clk(clk),
        .button_jump(button_jump),
        .button_duck(button_duck),
        .collision_pixel(collision_pixel),
        .dino_y(dino_y),
        .menu_reset_out(menu_reset_out),
        .dino_state(dino_state),
        .obs_x(obs_x),
        .obs_type(obs_type),
        .obs_y(obs_y),
        .horizon_offset(horizon_offset),
        .cloud_x(cloud_x)
    );

    // Instanciar o gerador de desenho
    draw game_draw (
        .clk(clk),
        .x_cnt(x_cnt),
        .y_cnt(y_cnt),
        .dino_y(dino_y),
        .dino_state(dino_state),
        .obs_x(obs_x),
        .obs_type(obs_type),
        .obs_y(obs_y),
        .horizon_offset(horizon_offset),
        .cloud_x(cloud_x),
        .collision_pixel(collision_pixel),
        .pixel_color(pixel_color)
    );

    // Clock de 27MHz -> Período de ~37ns (18.5ns em nível alto/baixo)
    always #18.5 clk = ~clk;

    integer frame;
    integer x, y;
    integer file;
    string filename;

    initial begin
        clk = 0;
        button_jump = 1; // Solto (Active Low)
        button_duck = 1; // Solto (Active Low)
        x_cnt = 0;
        y_cnt = 0;

        // Para visualizar ondas no GTKWave, descomente as linhas abaixo.
        // Cuidado: pode gerar arquivos .vcd grandes se a simulação rodar por muitos ciclos!
        // $dumpfile("sim_waveform.vcd");
        // $dumpvars(1, tb_game);
        // $dumpvars(1, tb_game.physics);

        $display("Iniciando simulacao do jogo...");
        
        // Espera um pouco
        #100;

        // Simula 180 frames (~3 segundos a 60 FPS)
        for (frame = 0; frame < 180; frame = frame + 1) begin
            // Faz o dinossauro pular no frame 20
            if (frame == 20) begin
                button_jump = 0; // Pressionado (Active Low)
                $display("Frame %0d: Botao de Pulo Pressionado!", frame);
            end
            if (frame == 25) begin
                button_jump = 1; // Solto
                $display("Frame %0d: Botao de Pulo Solto!", frame);
            end

            // Executa os ciclos de clock correspondentes a 1 frame (450000 ciclos)
            repeat (450005) @(posedge clk);

            // A cada 30 frames, vamos exportar o frame em formato PPM
            if (frame % 30 == 0) begin
                $sformat(filename, "assets/images_geradas/frame_%0d.ppm", frame);
                file = $fopen(filename, "w");
                if (file) begin
                    // Cabeçalho do arquivo PPM (formato P3, 240x135, max val 255)
                    $fwrite(file, "P3\n240 135\n255\n");
                    
                    for (y = 0; y < 135; y = y + 1) begin
                        for (x = 0; x < 240; x = x + 1) begin
                            x_cnt = x;
                            y_cnt = y;
                            
                            // Espera a leitura de memória síncrona
                            @(posedge clk);
                            #1;

                            // Desenha pixel branco ou preto
                            if (pixel_color == 16'hFFFF) begin
                                $fwrite(file, "255 255 255 "); // Branco
                            end else begin
                                $fwrite(file, "0 0 0 "); // Preto
                            end
                        end
                        $fwrite(file, "\n");
                    end
                    $fclose(file);
                    $display("Frame %0d exportado com sucesso para %s", frame, filename);
                end else begin
                    $display("Erro ao criar o arquivo PPM: %s. Certifique-se de que a pasta 'assets/images_geradas' existe.", filename);
                end
            end
        end

        $display("Simulacao concluida com sucesso!");
        $finish;
    end
endmodule