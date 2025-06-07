#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# CONFIG
SRC_DIR="/storage/emulated/0/Kustom/wallpapers"
DEST_ONEDRIVE="onedrive:/Termux/klwp"
LOGFILE="$HOME/scripts/klwp_backup.log"
VERSIONS_TO_KEEP=5   # Ou 3, personalize aqui
LOCKFILE="$HOME/.klwp_backup.lock"
DEBUG=true

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}
dbg() {
    $DEBUG && log "🕵️ $*"
}

exec 200>"$LOCKFILE"
flock -n 200 || { log "⚠️ Outro backup rodando – saindo."; exit 1; }

log ""
log "===== 🦇 KLWP ROOT ONLY VERSIONAMENTO ====="

# 1. Versiona local
backup_klwp_versions() {
    dbg "🔎 Procurando arquivos KLWP ‘master’ na raiz…"
    mapfile -t masters < <(
        find "$SRC_DIR" -maxdepth 1 -type f -name '*.klwp' \
            ! -name '*_v[0-9]*.klwp' | sort
    )
    if [ ${#masters[@]} -eq 0 ]; then
        log "ℹ️ Nenhum arquivo .klwp para versionar."
        return
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
        if [ "$lastver" -gt 0 ] && cmp -s "$filepath" "$dir/${base}_v${lastver}.klwp"; then
            dbg "🟡 $base sem mudanças desde v$lastver; pulando."
            continue
        fi
        newver=$((lastver + 1))
        newfile="$dir/${base}_v${newver}.klwp"
        cp -- "$filepath" "$newfile"
        log "🟢 Nova versão criada: $(basename "$newfile")"
        mapfile -t allvers < <(
            find "$dir" -maxdepth 1 -type f -name "${base}_v*.klwp" | sort -V
        )
        count=${#allvers[@]}
        if [ "$count" -gt "$VERSIONS_TO_KEEP" ]; then
            to_delete=$((count - VERSIONS_TO_KEEP))
            for old in "${allvers[@]:0:to_delete}"; do
                rm -f -- "$old"
                log "🗑️ Apagou versão antiga: $(basename "$old")"
            done
        fi
    done
    dbg "✅ Versionamento local finalizado."
}

# 2. Upload apenas arquivos .klwp versionados (apenas raiz!)
upload_klwp_versions_root() {
    log "🦇 Subindo arquivos versionados .klwp da raiz…"
    if ! rclone copy "$SRC_DIR/" "$DEST_ONEDRIVE/" \
        --include "*.klwp" \
        --include "*_v*.klwp" \
        --exclude "*/**" \
        --log-file="$LOGFILE" --log-level=INFO; then
        log "❌ Erro no upload das versões .klwp!"
        exit 2
    fi
    dbg "☁️ Upload dos versionados OK."
}

# 3. Prune remoto SÓ NA RAIZ da pasta remota klwp/
prune_remote_versions_root() {
    log "🧹 Limpando versões antigas só na raiz da nuvem…"
    mapfile -t bases < <(rclone lsf "$DEST_ONEDRIVE" --files-only --include "*_v*.klwp" | sed -E 's/_v[0-9]+\.klwp$//' | sort | uniq)
    for base in "${bases[@]}"; do
        mapfile -t remote_vers < <(rclone lsf "$DEST_ONEDRIVE" --files-only --include "${base}_v*.klwp" | sort -V)
        count=${#remote_vers[@]}
        if [ "$count" -gt "$VERSIONS_TO_KEEP" ]; then
            to_delete=$((count - VERSIONS_TO_KEEP))
            for oldfile in "${remote_vers[@]:0:to_delete}"; do
                rclone delete "$DEST_ONEDRIVE/$oldfile"
                log "🗑️ [REMOTE] Apagou $oldfile da nuvem (só raiz)"
            done
        fi
    done
    dbg "🧹 Limpeza remota raiz concluída."
}

# 4. Subpastas de klwp/ – backup incremental (sem apagar nada)
backup_subfolders_incremental() {
    log "🔄 Backup incremental das subpastas klwp/…"
    mapfile -t subdirs < <(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d)
    for sub in "${subdirs[@]}"; do
        subname=$(basename "$sub")
        log "🟢 Copiando incremental da subpasta: $subname"
        rclone copy "$sub" "$DEST_ONEDRIVE/$subname" \
            --log-file="$LOGFILE" --log-level=INFO --create-empty-src-dirs
    done
}

# 5. Outras pastas (scripts, termux_share_backup) – backup incremental
backup_other_folders_incremental() {
    for other in "scripts" "termux_share_backup"; do
        SRC="$HOME/$other"
        DEST="onedrive:/Termux/$other"
        [ -d "$SRC" ] && {
            log "🔄 Backup incremental de $other…"
            rclone copy "$SRC/" "$DEST/" --log-file="$LOGFILE" --log-level=INFO --create-empty-src-dirs
        }
    done
}

# EXECUÇÃO EM ORDEM
backup_klwp_versions
upload_klwp_versions_root
prune_remote_versions_root
backup_subfolders_incremental
backup_other_folders_incremental
log "✅ Bat-backup KLWP finalizado sem apagar subpastas ou outras áreas!"

