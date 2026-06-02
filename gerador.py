from PIL import Image

def converte_para_fpga(arquivo_entrada, arquivo_saida, canvas_largura=64, canvas_altura=40):
    try:
        # Abre a imagem original e converte para tons de cinza
        img = Image.open(arquivo_entrada).convert('L')
    except FileNotFoundError:
        print(f"Erro: O arquivo '{arquivo_entrada}' não foi encontrado na pasta.")
        return

    # Reduz a imagem mantendo a proporção original
    img.thumbnail((canvas_largura, canvas_altura), Image.Resampling.LANCZOS)
    
    # Cria o nosso "Canvas" fixo totalmente em branco
    canvas = Image.new('L', (canvas_largura, canvas_altura), color=255)
    
    # Calcula as coordenadas exatas para centralizar no X e colar no chão (Y)
    img_w, img_h = img.size
    offset_x = (canvas_largura - img_w) // 2 
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

    print(f"Sucesso! {arquivo_saida} gerado. (Tamanho original ocupado: {img_w}x{img_h})")

# ==========================================================
# LISTA DE SPRITES DO JOGO
# ==========================================================
sprites = [
    "dino",       # Parado / Pulando
    "dino-l",     # Correndo (Perna Esquerda)
    "dino-r",     # Correndo (Perna Direita)
    "dino-d",     # Morto (Game Over)
    "dino-d-l",   # Abaixado (Perna Esquerda)
    "dino-d-r"    # Abaixado (Perna Direita)
]

print("Iniciando conversão em lote...")

# Roda a função para cada nome na lista
for sprite in sprites:
    converte_para_fpga(f"{sprite}.png", f"{sprite}.txt")

print("\nTodos os arquivos foram gerados com sucesso para o FPGA!")
