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

# 0. Prepara marcador (se não existir, cria com epoch 0)
[ -f "$MARKER" ] || { touch -d @0 "$MARKER"; }

# 1. Procura masters modificados desde a última execução
mapfile -t changed < <(
  find "$SRC_DIR" -maxdepth 1 -type f \( -iname '*.klwp' -o -iname '*.kwgt' \) \
       ! -name '*_v[0-9]*.*' -newer "$MARKER"
)

if [ ${#changed[@]} -eq 0 ]; then
  log "ℹ️ Nenhum .klwp/.kwgt mudou desde última vez."
else
  for fp in "${changed[@]}"; do
    base=$(basename "$fp")
    name="${base%.*}"
    ext="${base##*.}"
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

    # Copia master + versão para nuvem
    log "🟢 Versionando $base → $target"
    rclone copyto "$fp" "$DEST/$target" \
      --log-file="$LOG" --log-level INFO

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

# 2. Backup completo de subpastas (sempre integral)
log "🔄 Backup incremental de subpastas…"
for sub in "$SRC_DIR"/*/; do
  [ -d "$sub" ] && {
    name=$(basename "$sub")
    rclone copy "$sub" "$DEST/$name" --log-file="$LOG" --log-level INFO
  }
done

# 3. Atualiza marcador para agora
touch "$MARKER"
log "✅ Tudo versionado e subpastas copiados. Marker atualizado."