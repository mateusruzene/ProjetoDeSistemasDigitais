import os
import subprocess
from PIL import Image

def main():
    # Garante que roda no diretório do script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    
    print("=== Simulação e Renderização do Dino Game ===")
    
    # Certifica-se de que a pasta assets/images_geradas existe
    os.makedirs("assets/images_geradas", exist_ok=True)
    
    # Limpa arquivos PNG e PPM gerados anteriormente na pasta assets/images_geradas/
    print("\n[0/3] Limpando frames anteriores em assets/images_geradas/...")
    for file in os.listdir("assets/images_geradas"):
        if file.startswith("frame_") and (file.endswith(".png") or file.endswith(".ppm")):
            try:
                os.remove(os.path.join("assets/images_geradas", file))
            except OSError:
                pass

    # 1. Compilar os arquivos Verilog
    print("\n[1/3] Compilando arquivos Verilog com iverilog...")
    compile_cmd = ["iverilog", "-g2012", "-o", "sim_game", "tb_game.v", "game.v", "draw.v"]
    try:
        subprocess.run(compile_cmd, check=True)
        print("Compilação concluída com sucesso! (Executável 'sim_game' gerado)")
    except subprocess.CalledProcessError as e:
        print(f"Erro na compilação Verilog: {e}")
        return
    except FileNotFoundError:
        print("Erro: 'iverilog' não foi encontrado no sistema. Instale-o com: brew install icarus-verilog")
        return

    # 2. Rodar a simulação
    print("\n[2/3] Executando simulação com vvp...")
    run_cmd = ["vvp", "sim_game"]
    try:
        subprocess.run(run_cmd, check=True)
        print("Simulação concluída com sucesso!")
    except subprocess.CalledProcessError as e:
        print(f"Erro ao executar a simulação: {e}")
        return

    # 3. Converter imagens PPM geradas para PNG
    print("\n[3/3] Convertendo arquivos PPM gerados para PNG...")
    files_converted = 0
    target_dir = "assets/images_geradas"
    
    for file in os.listdir(target_dir):
        if file.startswith("frame_") and file.endswith(".ppm"):
            ppm_path = os.path.join(target_dir, file)
            png_path = ppm_path.replace(".ppm", ".png")
            try:
                with Image.open(ppm_path) as img:
                    # Redimensiona a imagem pixel-art usando NEAREST para ficar nítida e maior
                    w, h = img.size
                    scale = 4  # Aumenta 4x (960x540)
                    resized_img = img.resize((w * scale, h * scale), Image.Resampling.NEAREST)
                    resized_img.save(png_path)
                # Deleta o arquivo PPM temporário
                os.remove(ppm_path)
                print(f"Gerado: {png_path} (Escala {scale}x: {w*scale}x{h*scale})")
                files_converted += 1
            except Exception as e:
                print(f"Erro ao converter {file}: {e}")
                
    if files_converted > 0:
        print(f"\nSucesso! {files_converted} frames convertidos para PNG e salvos em 'assets/images_geradas/'.")
        print("Você pode abrir a pasta 'assets/images_geradas' para ver o estado do jogo em diferentes frames!")
    else:
        print("\nNenhum arquivo de imagem gerado pela simulação.")

if __name__ == "__main__":
    main()