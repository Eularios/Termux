#!/data/data/com.termux/files/usr/bin/bash

logfile="$HOME/scripts/termux_scripts.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Executado: $0 $@" >> "$logfile"

# === Variáveis ===
BACKDIR="$HOME/storage/shared/termux_share/backup"
LOCAL_SCRIPTS="$HOME/scripts"
ONEDRIVE_BACKUP="onedrive:/Termux/termux_share_backup/"
ONEDRIVE_SCRIPTS="onedrive:/Termux/scripts"
mkdir -p "$BACKDIR"

# === Backup rotativo ===
NOW=$(date +%Y%m%d_%H%M%S)
TARFILE="$BACKDIR/backup_$NOW.tar.gz"
PKGLIST="$BACKDIR/pkglist_$NOW.txt"
LOGCOPY="$BACKDIR/termux_scripts_$NOW.log"

echo "🔹 Salvando lista de pacotes..."
dpkg --get-selections > "$PKGLIST"
echo "🔹 Fazendo cópia do log para backup..."
cp "$logfile" "$LOGCOPY"

echo "🔹 Gerando backup (.bashrc, rclone.conf, scripts)..."
tar -czvf "$TARFILE" \
    --exclude-from="$LOCAL_SCRIPTS/.backupignore" \
    "$HOME/.bashrc" \
    "$HOME/.config/rclone/rclone.conf" \
    "$LOCAL_SCRIPTS" \
    "$PKGLIST" \
    "$LOGCOPY"

# === Mantém só as 3 últimas versões dos backups, pkglist e logs ===
ls -1t "$BACKDIR"/backup_*.tar.gz | tail -n +4 | xargs -r rm -f
ls -1t "$BACKDIR"/pkglist_*.txt | tail -n +4 | xargs -r rm -f
ls -1t "$BACKDIR"/termux_scripts_*.log | tail -n +4 | xargs -r rm -f

echo -e "\e[1;32m✅ Backup salvo em $TARFILE\e[0m"

# === Proteção contra wipe (não usar --delete-during, só --copy-links, etc.) ===
echo "🔹 Sincronizando backups para a nuvem (proteção contra wipe)..."
rclone copy "$BACKDIR" "$ONEDRIVE_BACKUP" --update --progress | tee -a "$logfile"

# Sincronização apenas de novas/alteradas (não remove da nuvem!)
echo "🔹 Sincronizando scripts da nuvem para o Termux (one-way sync, sem deletar local)..."
rclone copy "$ONEDRIVE_SCRIPTS" "$LOCAL_SCRIPTS" --update --progress | tee -a "$logfile"

echo "✅ Backup limpo, rotacionado e sync de scripts concluído!"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup e sync concluídos!" >> "$logfile"
