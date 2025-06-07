#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

#
# CONFIGURATION (can override via ~/.klwp_backup.conf)
#
CONFIG_FILE="$HOME/.klwp_backup.conf"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

SRC_DIR="${SRC_DIR:-/storage/emulated/0/Kustom/wallpapers}"
DEST_ONEDRIVE="${DEST_ONEDRIVE:-onedrive:/Termux/klwp}"
LOGFILE="${LOGFILE:-$HOME/Scripts/klwp_backup.log}"
VERSIONS_TO_KEEP="${VERSIONS_TO_KEEP:-3}"
ARCHIVE_OLDER_DAYS="${ARCHIVE_OLDER_DAYS:-30}"
LOCKFILE="${LOCKFILE:-$HOME/.klwp_backup.lock}"

#
# Logging & helper functions.
#
mkdir -p "$(dirname "$LOGFILE")"
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

# Clean exit on Ctrl+C
trap 'log "⚠️ Interrupted! Exiting."; exit 1' INT TERM

#
# Flags: -n = dry-run, -v = verbose (rclone --progress)
#
DRY_RUN=false
VERBOSE=false
while getopts "nv" opt; do
  case $opt in
    n) DRY_RUN=true ;;
    v) VERBOSE=true ;;
    *) echo "Usage: $0 [-n dry-run] [-v verbose]" >&2; exit 1 ;;
  esac
done
shift $((OPTIND-1))

#
# Build rclone options (timeouts, retries, dry-run/verbose)
#
RCLONE_OPTS=(
  --timeout=1m
  --contimeout=30s
  --retries=3
  --low-level-retries=10
)
$DRY_RUN  && RCLONE_OPTS+=(--dry-run)
$VERBOSE && RCLONE_OPTS+=(--progress)

#
# Rotate log if too big
#
if [ -f "$LOGFILE" ] && [ "$(wc -l <"$LOGFILE")" -gt 5000 ]; then
  tail -n 1000 "$LOGFILE" >"${LOGFILE}.tmp"
  mv "${LOGFILE}.tmp" "$LOGFILE"
fi

#
# Prevent concurrent runs
#
exec 200>"$LOCKFILE"
flock -n 200 || { log "⚠️ Another backup is running—exiting."; exit 1; }

log "===== 🦇 KLWP Backup started ====="

#
# 1) Versioning: create _vN copies, prune old
#
backup_klwp_versions() {
  mapfile -t masters < <(
    find "$SRC_DIR" -maxdepth 1 -type f -name '*.klwp' \
         ! -name '*_v[0-9]*.klwp' | sort
  )
  if [ ${#masters[@]} -eq 0 ]; then
    log "ℹ️ No .klwp files to version"
    return
  fi

  for filepath in "${masters[@]}"; do
    base="$(basename "${filepath%.klwp}")"
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
      log "🟡 $base unchanged since v$lastver; skipping."
      continue
    fi

    newver=$((lastver+1))
    newfile="$dir/${base}_v${newver}.klwp"
    cp -- "$filepath" "$newfile"
    log "🟢 Created version: $(basename "$newfile")"

    mapfile -t allvers < <(
      find "$dir" -maxdepth 1 -type f -name "${base}_v*.klwp" | sort -V
    )
    count=${#allvers[@]}
    if [ "$count" -gt "$VERSIONS_TO_KEEP" ]; then
      to_delete=$((count - VERSIONS_TO_KEEP))
      for old in "${allvers[@]:0:to_delete}"; do
        rm -f -- "$old"
        log "🗑️ Deleted old version: $(basename "$old")"
      done
    fi
  done
}

#
# 2) Archive old versions (> ARCHIVE_OLDER_DAYS)
#
archive_old_versions() {
  ARCHIVE_DIR="$SRC_DIR/archives"
  mkdir -p "$ARCHIVE_DIR"
  command -v zip >/dev/null || { log "⚠️ zip not installed—skipping archive"; return; }

  mapfile -t old_files < <(
    find "$SRC_DIR" -maxdepth 1 -type f -name '*_v*.klwp' \
         -mtime +"$ARCHIVE_OLDER_DAYS"
  )
  if [ ${#old_files[@]} -gt 0 ]; then
    archive_name="$ARCHIVE_DIR/archive-$(date +%Y-%m).zip"
    zip -j "$archive_name" "${old_files[@]}"
    log "🗜️ Archived ${#old_files[@]} files into $(basename "$archive_name")"
    $DRY_RUN || { rm -f -- "${old_files[@]}"; log "🗑️ Removed archived files"; }
  else
    log "ℹ️ No versions older than $ARCHIVE_OLDER_DAYS days to archive"
  fi
}

backup_klwp_versions
archive_old_versions

#
# 3) Upload versioned .klwp files
#
log "➤ Starting rclone copy of .klwp versions…"
rclone copy \
  "$SRC_DIR/" "$DEST_ONEDRIVE/" \
  --include "*_v*.klwp" \
  --stats 5s --stats-one-line \
  "${RCLONE_OPTS[@]}" \
  --log-file="$LOGFILE" --log-level=INFO
log "<<< rclone copy of .klwp versions done"

#
# 4) Integrity check
#
log "🔍 Integrity check of versioned files…"
if ! rclone check \
       "$SRC_DIR" "$DEST_ONEDRIVE/" \
       --include "*_v*.klwp" \
       --log-file="$LOGFILE" --log-level=ERROR; then
  log "⚠️ Integrity check detected mismatches!"
fi

#
# 5) Sync everything else
#
log "➤ Starting rclone sync of other files…"
rclone sync \
  "$SRC_DIR/" "$DEST_ONEDRIVE/" \
  --exclude "*.klwp" --exclude "*_v*.klwp" \
  --stats 5s --stats-one-line \
  "${RCLONE_OPTS[@]}" \
  --log-file="$LOGFILE" --log-level=INFO
log "<<< rclone sync of other files done"

#
# 6) Notification & finish
#
if command -v termux-notification >/dev/null; then
  termux-notification \
    --title "KLWP Backup" \
    --content "Done: kept $VERSIONS_TO_KEEP versions; archived >${ARCHIVE_OLDER_DAYS}d" \
    --priority high
fi

log "✅ KLWP Backup complete!"
