#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# CONFIGURAÇÃO
SRC_DIR="/storage/emulated/0/Kustom/wallpapers"
DEST_ONEDRIVE="onedrive:/Termux/klwp"
LOGFILE="$HOME/scripts/klwp_backup.log"
VERSIONS_TO_KEEP=5

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

log ""
log "===== 🦇 KLWP BACKUP VERSIONADO (local + nuvem) ====="

# 1. Versiona local
mapfile -t masters < <(
    find "$SRC_DIR" -maxdepth 1 -type f -name '*.klwp' \
        ! -name '*_v[0-9]*.klwp' | sort
)
if [ ${#masters[@]} -eq 0 ]; then
    log "ℹ️ Nenhum arquivo .klwp para versionar."
    exit 0
fi

for filepath in "${masters[@]}"; do
    filename=$(basename "$filepath")
    base="${filename%.klwp}"
    dir="$(dirname "$filepath")"
    mapfile -t versions < <(
        find "$dir" -maxdepth 1 -type f -name "${base}_v*.klwp" | sort -V
    )
    if [ ${#versions[@]} -gt 0 ]; then
        last="${versions[-1]}"
        lastver=$(printf '%s\n' "$last" | sed -E 's/.*_v([0-9]+)\.klwp$/\1/')
    else
        lastver=0
    fi
    # Só cria nova versão se mudou de fato
    if [ "$lastver" -gt 0 ] && cmp -s "$filepath" "$dir/${base}_v${lastver}.klwp"; then
        log "🟡 $base sem mudanças desde v$lastver; pulando."
        continue
    fi
    newver=$((lastver + 1))
    newfile="$dir/${base}_v${newver}.klwp"
    cp -- "$filepath" "$newfile"
    log "🟢 Nova versão local criada: $(basename "$newfile")"
    # Limita versões locais
    mapfile -t allvers < <(
        find "$dir" -maxdepth 1 -type f -name "${base}_v*.klwp" | sort -V
    )
    count=${#allvers[@]}
    if [ "$count" -gt "$VERSIONS_TO_KEEP" ]; then
        to_delete=$((count - VERSIONS_TO_KEEP))
        for old in "${allvers[@]:0:to_delete}"; do
            rm -f -- "$old"
            log "🗑️ Apagou versão local antiga: $(basename "$old")"
        done
    fi
done

# 2. Sobe para nuvem (apenas .klwp e versões, raiz)
log "☁️ Subindo versões para nuvem (OneDrive)…"
if ! rclone copy "$SRC_DIR/" "$DEST_ONEDRIVE/" \
    --filter "+ *.klwp" \
    --filter "+ *_v*.klwp" \
    --filter "- **" \
    --log-file="$LOGFILE" --log-level=INFO; then
    log "❌ Erro no upload das versões .klwp!"
    exit 2
fi

# 3. Mantém no máximo N versões na nuvem (raiz)
log "🧹 Limpando versões antigas na nuvem (OneDrive)…"
mapfile -t bases < <(rclone lsf "$DEST_ONEDRIVE" --files-only --include "*_v*.klwp" | sed -E 's/_v[0-9]+\.klwp$//' | sort | uniq)
for base in "${bases[@]}"; do
    mapfile -t remote_vers < <(rclone lsf "$DEST_ONEDRIVE" --files-only --include "${base}_v*.klwp" | sort -V)
    count=${#remote_vers[@]}
    if [ "$count" -gt "$VERSIONS_TO_KEEP" ]; then
        to_delete=$((count - VERSIONS_TO_KEEP))
        for oldfile in "${remote_vers[@]:0:to_delete}"; do
            rclone delete "$DEST_ONEDRIVE/$oldfile"
            log "🗑️ [REMOTE] Apagou versão antiga da nuvem: $oldfile"
        done
    fi
done

log "✅ Backup versionado local + nuvem concluído!"
