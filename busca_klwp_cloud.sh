#!/data/data/com.termux/files/usr/bin/bash

# Pasta de destino local
DEST="/storage/emulated/0/Kustom_restore/wallpapers/klwp_bak"
mkdir -p "$DEST"

# Lista arquivos em array
mapfile -t ARQUIVOS < <(rclone lsf "onedrive:/Termux/klwp" | grep -v '/$')

if [ ${#ARQUIVOS[@]} -eq 0 ]; then
    echo "Nenhum arquivo encontrado na nuvem!"
    exit 1
fi

echo "Arquivos disponíveis na nuvem:"
for i in "${!ARQUIVOS[@]}"; do
    printf "  %2d: %s\n" $((i+1)) "${ARQUIVOS[$i]}"
done

echo
read -p "Escolha o número do arquivo para baixar: " NUM

if ! [[ "$NUM" =~ ^[0-9]+$ ]] || [ "$NUM" -lt 1 ] || [ "$NUM" -gt "${#ARQUIVOS[@]}" ]; then
    echo "Escolha inválida. Saindo..."
    exit 1
fi

ARQUIVO_ESCOLHIDO="${ARQUIVOS[$((NUM-1))]}"
echo "Baixando '$ARQUIVO_ESCOLHIDO'..."
rclone copy "onedrive:/Termux/klwp/$ARQUIVO_ESCOLHIDO" "$DEST/"

if [ $? -eq 0 ]; then
    echo "✅ Arquivo '$ARQUIVO_ESCOLHIDO' baixado com sucesso para $DEST"
else
    echo "❌ Falha ao baixar o arquivo."
fi
