import os
from PIL import Image

# Garante que o script roda no diretório em que ele está localizado
script_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(script_dir)

def converte_para_fpga(nome_sprite, canvas_largura=64, canvas_altura=40):
    arquivo_entrada = f"assets/images/{nome_sprite}.png"
    arquivo_saida = f"assets/texturas/{nome_sprite}.txt"
    
    # Cria o diretório de destino se não existir
    os.makedirs(os.path.dirname(arquivo_saida), exist_ok=True)
    
    try:
        # Abre a imagem original e converte para tons de cinza
        img = Image.open(arquivo_entrada).convert('L')
    except FileNotFoundError:
        print(f"Aviso: O arquivo '{arquivo_entrada}' não foi encontrado na pasta (pulado).")
        return

    # Reduz a imagem mantendo a proporção original
    img.thumbnail((canvas_largura, canvas_altura), Image.Resampling.LANCZOS)
    
    # Cria o nosso "Canvas" fixo totalmente em branco
    canvas = Image.new('L', (canvas_largura, canvas_altura), color=255)
    
    # Calcula as coordenadas exatas para centralizar no X e colar no chão (Y)
    img_w, img_h = img.size
    offset_x = (canvas_largura - img_w) // 2 
    if nome_sprite == "horizon":
        offset_y = 28  # Posiciona o solo na linha 28 do Canvas para ficar visível (FLOOR_Y + 28 = Y 125)
    else:
        offset_y = canvas_altura - img_h
    
    # Cola o dinossauro desenhado dentro do Canvas
    canvas.paste(img, (offset_x, offset_y))
    
    # Faz a varredura gerando o TXT
    with open(arquivo_saida, 'w') as f:
        for y in range(canvas_altura):
            row_str = ""
            for x in range(canvas_largura):
                pixel = canvas.getpixel((x, y))
                if pixel < 128:
                    row_str += "1"
                else:
                    row_str += "0"
            f.write(row_str + "\n")

    print(f"Sucesso! {nome_sprite}.txt gerado em assets/texturas/ (Tamanho original: {img_w}x{img_h})")

# ==========================================================
# LISTA DE SPRITES DO JOGO
# ==========================================================
sprites = [
    "dino",           # Parado / Pulando
    "dino-l",         # Correndo (Perna Esquerda)
    "dino-r",         # Correndo (Perna Direita)
    "dino-d",         # Morto (Game Over)
    "dino-d-l",       # Abaixado (Perna Esquerda)
    "dino-d-r",       # Abaixado (Perna Direita)
    "cactus",         # Cacto simples
    "cactus-triple",  # Cacto triplo
    "pterodactyl",    # Pterodáctilo
    "horizon",        # Chão/Cenário
    "cloud",          # Nuvem
    "restart",        # Botão de Restart
]

print("Iniciando conversão em lote...")

# Roda a função para cada nome na lista
for sprite in sprites:
    converte_para_fpga(sprite)

print("\nTodos os arquivos existentes foram processados e salvos em assets/texturas/!")
