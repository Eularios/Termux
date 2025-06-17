#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Config
SRC_DIR="/storage/emulated/0/Kustom/wallpapers"
DEST="onedrive:/Termux/klwp"
LOG="$HOME/scripts/klwp_backup.log"
VERSIONS=5
MARKER="$HOME/.klwp_backup.lastrun"

log(){ echo "[$(date '+%F %T')] $*"|tee -a "$LOG"; }

log "🟠 Arquivos na origem ANTES do backup:"
ls -1 "$SRC_DIR" | tee -a "$LOG"

# 0. Prepara marcador (se não existir, cria com epoch 0)
[ -f "$MARKER" ] || { touch -d @0 "$MARKER"; }

# 1. Procura masters modificados desde a última execução
mapfile -t changed < <(
  find "$SRC_DIR" -maxdepth 1 -type f \( -iname '*.klwp' -o -iname '*.kwgt' \) \
       ! -name '*_v[0-9]*.*' -newer "$MARKER"
)

log "🔵 Arquivos detectados para versionar: (${#changed[@]})"
for f in "${changed[@]}"; do log "    - $f"; done

if [ ${#changed[@]} -eq 0 ]; then
  log "ℹ️ Nenhum .klwp/.kwgt mudou desde última vez."
else
  for fp in "${changed[@]}"; do
    log "🔹 Iniciando processamento de $fp"
    base=$(basename "$fp")
    name="${base%.*}"
    ext="${base##*.}"

    log "   - Base: $base | Name: $name | Ext: $ext"
    log "   - Arquivos na origem DURANTE processamento:"
    ls -1 "$SRC_DIR" | tee -a "$LOG"

    # Listar versões remotas atuais
    mapfile -t remote_vers < <(
      rclone lsf "$DEST" --files-only --include "${name}_v*.${ext}" | sort -V
    )

    # Calcula próximo número
    if [ ${#remote_vers[@]} -gt 0 ]; then
      last=${remote_vers[-1]}
      num=${last##*_v}; num=${num%.*}
    else
      num=0
    fi
    new=$((num+1))
    target="${name}_v${new}.${ext}"

    log "🟢 Enviando para nuvem: $fp → $DEST/$target"
    rclone copyto "$fp" "$DEST/$target" \
      --log-file="$LOG" --log-level INFO

    log "🟢 (Após upload) Arquivos na origem:"
    ls -1 "$SRC_DIR" | tee -a "$LOG"

    # Limita versões na nuvem
    mapfile -t all < <(
      rclone lsf "$DEST" --files-only --include "${name}_v*.${ext}" | sort -V
    )
    if [ ${#all[@]} -gt $VERSIONS ]; then
      remove_cnt=$(( ${#all[@]} - VERSIONS ))
      for old in "${all[@]:0:remove_cnt}"; do
        log "🗑️ [REMOTE] Apagando $old"
        rclone delete "$DEST/$old"
      done
    fi
  done
fi

log "🟠 Arquivos na origem DEPOIS do loop de versionamento:"
ls -1 "$SRC_DIR" | tee -a "$LOG"

# 2. Backup completo de subpastas (sempre integral)
log "🔄 Backup incremental de subpastas…"
for sub in "$SRC_DIR"/*/; do
  [ -d "$sub" ] && {
    name=$(basename "$sub")
    log "🟢 Copiando subpasta: $sub → $DEST/$name"
    rclone copy "$sub" "$DEST/$name" --log-file="$LOG" --log-level INFO
    log "🟢 (Após copiar subpasta) Arquivos na origem:"
    ls -1 "$SRC_DIR" | tee -a "$LOG"
  }
done

# 3. Atualiza marcador para agora
touch "$MARKER"
log "✅ Tudo versionado e subpastas copiados. Marker atualizado."
