#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# CONFIG
SRC_DIR="/storage/emulated/0/Kustom/wallpapers"
DEST_ONEDRIVE="onedrive:/Termux/klwp"
LOGFILE="$HOME/scripts/klwp_backup.log"
VERSIONS_TO_KEEP=3
LOCKFILE="$HOME/.klwp_backup.lock"
DEBUG=true   # coloque false para menos prints

# Logging functions
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}
dbg() {
    $DEBUG && log "🕵️ $*"
}

# LOCK para não rodar duplo
exec 200>"$LOCKFILE"
flock -n 200 || { log "⚠️ Outro backup rodando – saindo."; exit 1; }

log ""
log "===== 🦇 Bat-backup KLWP NINJA iniciado ====="

# 1. VERSIONAMENTO LOCAL
backup_klwp_versions() {
    dbg "🔎 Procurando arquivos KLWP ‘master’…"
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
                log "🗑️  Apagou versão antiga: $(basename "$old")"
            done
        fi
    done
    dbg "✅ Versionamento local finalizado."
}

# 2. TESTA ACESSO AO ONEDRIVE
test_rclone() {
    dbg "🔌 Testando acesso ao OneDrive (rclone)..."
    if ! rclone lsf "$DEST_ONEDRIVE" >/dev/null 2>&1; then
        log "❌ Falha ao acessar $DEST_ONEDRIVE – verifique rclone/config."
        exit 1
    fi
    dbg "🔗 Acesso ao OneDrive OK."
}

# 3. UPLOAD DOS VERSIONADOS
upload_versions() {
    log "🦇 Enviando arquivos versionados (.klwp) para nuvem…"
    if ! rclone copy "$SRC_DIR/" "$DEST_ONEDRIVE/" \
        --include "*_v*.klwp" --log-file="$LOGFILE" --log-level=INFO; then
        log "❌ Erro no upload de versões .klwp para o OneDrive!"
        exit 2
    fi
    dbg "☁️ Upload dos versionados OK."
}

# 4. PRUNE REMOTO (LIMPA VERSÕES ANTIGAS NO ONEDRIVE)
prune_remote_versions() {
    log "🧹 Limpando versões antigas na nuvem…"
    mapfile -t bases < <(rclone lsf "$DEST_ONEDRIVE" --include "*_v*.klwp" | sed -E 's/_v[0-9]+\.klwp$//' | sort | uniq)
    for base in "${bases[@]}"; do
        mapfile -t remote_vers < <(rclone lsf "$DEST_ONEDRIVE" --include "${base}_v*.klwp" | sort -V)
        count=${#remote_vers[@]}
        if [ "$count" -gt "$VERSIONS_TO_KEEP" ]; then
            to_delete=$((count - VERSIONS_TO_KEEP))
            for oldfile in "${remote_vers[@]:0:to_delete}"; do
                rclone delete "$DEST_ONEDRIVE/$oldfile"
                log "🗑️ [REMOTE] Apagou $oldfile da nuvem"
            done
        fi
    done
    dbg "🧹 Limpeza remota concluída."
}

# 5. SYNC OUTROS ARQUIVOS
sync_others() {
    log "🦇 Sincronizando demais arquivos (excluindo .klwp)…"
    if ! rclone sync "$SRC_DIR/" "$DEST_ONEDRIVE/" \
        --exclude "*.klwp" --exclude "*_v*.klwp" \
        --create-empty-src-dirs \
        --log-file="$LOGFILE" --log-level=INFO --ignore-errors; then
        log "❌ Erro ao sincronizar demais arquivos!"
        exit 3
    fi
    dbg "✅ Sincronização dos demais arquivos OK."
}

# 6. FINALIZAÇÃO
finish() {
    log "✅ Bat-backup KLWP NINJA concluído!"
    if command -v termux-notification >/dev/null; then
        termux-notification --title "KLWP Backup" --content "Backup KLWP finalizado sem erro" --priority high
    fi
}

#########################
# EXECUÇÃO EM ORDEM BATMAN #
#########################
backup_klwp_versions
test_rclone
upload_versions
prune_remote_versions
sync_others
finish

