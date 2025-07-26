#!/data/data/com.termux/files/usr/bin/bash

logfile="$HOME/scripts/termux_restore.log"
RESTORE_DIR="$HOME/storage/shared/termux_share/restore"
ONEDRIVE_BACKUP="onedrive:/Termux/termux_share_backup/"

mkdir -p "$RESTORE_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RESTORE] Iniciando restore..." >> "$logfile"

# Baixa todos os backups
echo "🔹 Baixando backups da nuvem..."
rclone copy "$ONEDRIVE_BACKUP" "$RESTORE_DIR" --update --progress | tee -a "$logfile"

# Encontra o backup mais recente
LATEST_BACKUP=$(ls -1t $RESTORE_DIR/backup_*.tar.gz | head -n1)
if [ -z "$LATEST_BACKUP" ]; then
    echo "❌ Nenhum arquivo de backup encontrado!"
    exit 1
fi

echo "🔹 Extraindo backup mais recente: $LATEST_BACKUP"
tar -xzvf "$LATEST_BACKUP" -C $HOME

# Restaurar pkglist (opcional, só se quiser mesmo)
PKGLIST=$(ls -1t $RESTORE_DIR/pkglist_*.txt | head -n1)
if [ -n "$PKGLIST" ]; then
    echo "🔹 Instalando pacotes listados..."
    cut -f1 "$PKGLIST" | xargs -n1 pkg install -y
fi

echo -e "\e[1;32m✅ Restore concluído! Reinicie o Termux para garantir as configs.\e[0m"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RESTORE] Restore concluído!" >> "$logfile"
