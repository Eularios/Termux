#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# CONFIGURAÇÃO
default_src="/storage/emulated/0/Kustom/wallpapers"
SRC_DIR="${1:-$default_src}"
DEST_ONEDRIVE="onedrive:/Termux/klwp"
LOGFILE="$HOME/scripts/klwp_backup.log"
VERSIONS_TO_KEEP=5

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

log "==== 🦇 KLWP BACKUP ENHANCED (remote versioning + full subfolder sync) ===="

# Função para obter checksum MD5 local ou remoto
md5_local() {
    md5sum "$1" 2>/dev/null | awk '{print $1}' || echo
}
md5_remote() {
    # rclone md5sum retorna: <hash>  <path>
    rclone md5sum "$1" 2>/dev/null | awk '{print $1}' || echo
}

# 1. Versionamento remoto para arquivos .klwp e .kwgt na raiz
log "🔄 Processando versionamento remoto de .klwp e .kwgt na raiz..."
mapfile -t roots < <(
    find "$SRC_DIR" -maxdepth 1 -type f \( -iname '*.klwp' -o -iname '*.kwgt' \) | sort
)
for filepath in "${roots[@]}"; do
    filename=$(basename "$filepath")
    ext="${filename##*.}"
    base="${filename%.*}"

    # Lista versões remotas existentes
    mapfile -t remotes < <(
        rclone lsf "$DEST_ONEDRIVE" --files-only --include "${base}_v*.${ext}" | sort -V
    )
    if [ ${#remotes[@]} -gt 0 ]; then
        # Última versão remota
        last_remote="${remotes[-1]}"
        lastver=$(printf '%s' "$last_remote" | sed -E 's/.*_v([0-9]+)\.'"$ext""$/\1/')
    else
        lastver=0
    fi

    # Compare checksums para detectar mudança
    if [ "$lastver" -gt 0 ]; then
        # caminho remoto completo
        remote_path="$DEST_ONEDRIVE/$last_remote"
        remote_md5=$(md5_remote "$remote_path")
        local_md5=$(md5_local "$filepath")
        if [ -n "$remote_md5" ] && [ "$remote_md5" == "$local_md5" ]; then
            log "🟡 $filename não alterado desde v$lastver; pulando."
            continue
        fi
    fi

    # Nova versão: incrementa contador
    newver=$((lastver + 1))
    newremote="${base}_v${newver}.${ext}"
    log "🟢 Criando versão remota: $newremote"
    # Copia para Onedrive renomeando
    rclone copyto "$filepath" "$DEST_ONEDRIVE/$newremote" --log-file="$LOGFILE" --log-level=INFO

    # Prune: mantém só VERSIONS_TO_KEEP
    mapfile -t all_remotes < <(
        rclone lsf "$DEST_ONEDRIVE" --files-only --include "${base}_v*.${ext}" | sort -V
    )
    count=${#all_remotes[@]}
    if [ $count -gt $VERSIONS_TO_KEEP ]; then
        delcount=$((count - VERSIONS_TO_KEEP))
        for old in "${all_remotes[@]:0:delcount}"; do
            log "🗑️ Removendo versão antiga na nuvem: $old"
            rclone delete "$DEST_ONEDRIVE/$old"
        done
    fi

done

# 2. Full sync de subpastas (backup integral, sem deleção)
log "🔄 Full sync de subpastas para nuvem (sem deleções)..."
mapfile -t subdirs < <(
    find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d | sort
)
for sub in "${subdirs[@]}"; do
    name=$(basename "$sub")
    log "📂 Sincronizando $name..."
    # copy mantém arquivos novos e alterados, não apaga nada no dest
    rclone copy "$sub" "$DEST_ONEDRIVE/$name" --create-empty-src-dirs --log-file="$LOGFILE" --log-level=INFO

done

log "✅ KLWP remote versioning + full subfolder sync finalizado!"
