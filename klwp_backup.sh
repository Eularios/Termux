#!/data/data/com.termux/files/usr/bin/env bash
set -e -u -o pipefail
IFS=$'\n\t'

# ──────────── External config ────────────
CONFIG_FILE="$HOME/.klwp_backup.conf"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# ──────────── Defaults ────────────
SRC_DIR="${SRC_DIR:-/storage/emulated/0/Kustom/wallpapers}"
DEST_ONEDRIVE="${DEST_ONEDRIVE:-onedrive:/Termux/klwp}"
LOGFILE="${LOGFILE:-$HOME/scripts/klwp_backup.log}"
VERSIONS_TO_KEEP="${VERSIONS_TO_KEEP:-3}"
ARCHIVE_OLDER_DAYS="${ARCHIVE_OLDER_DAYS:-30}"
LOCKFILE="${LOCKFILE:-$HOME/.klwp_backup.lock}"

# ──────────── Logging fn & init ────────────
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

# Ensure log directory exists
mkdir -p "$(dirname "$LOGFILE")"

# ──────────── Flags parsing ────────────
DRY_RUN=false
VERBOSE=false
while getopts "nv" opt; do
    case "$opt" in
        n) DRY_RUN=true   ;;  # dry-run
        v) VERBOSE=true   ;;  # show rclone progress
        *) echo "Usage: $0 [-n dry-run] [-v verbose]" >&2; exit 1 ;;
    esac
done
shift $((OPTIND-1))

RCLONE_OPTS=()
$DRY_RUN  && RCLONE_OPTS+=(--dry-run)
$VERBOSE && RCLONE_OPTS+=(--progress)

# ──────────── Log rotation ────────────
if [ -f "$LOGFILE" ] && [ "$(wc -l <"$LOGFILE")" -gt 5000 ]; then
    tail -n 1000 "$LOGFILE" >"${LOGFILE}.tmp"
    mv "${LOGFILE}.tmp" "$LOGFILE"
fi

# ──────────── Concurrency lock ────────────
exec 200>"$LOCKFILE"
flock -n 200 || { log "⚠️  Another backup is running—exiting."; exit 1; }

# ──────────── Clean exit on Ctrl+C ────────────
trap 'log "⚠️ Interrupted, exiting."; exit 1' INT TERM

log "===== 🦇 KLWP Backup started ====="

# ──────────── 1) Versioning ────────────
backup_klwp_versions() {
    mapfile -t masters < <(
        find "$SRC_DIR" -maxdepth 1 -type f -name '*.klwp' \
             ! -name '*_v[0-9]*.klwp' | sort
    )
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

        newver=$((lastver + 1))
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

# ──────────── 2) Archive old versions ────────────
archive_old_versions() {
    local ARCHIVE_DIR="$SRC_DIR/archives"
    mkdir -p "$ARCHIVE_DIR"

    if ! command -v zip >/dev/null; then
        log "⚠️ zip not installed; skipping archiving."
        return
    fi

    mapfile -t old_files < <(
        find "$SRC_DIR" -maxdepth 1 -type f -name '*_v*.klwp' -mtime +"$ARCHIVE_OLDER_DAYS"
    )

    if [ ${#old_files[@]} -gt 0 ]; then
        local archive_name="$ARCHIVE_DIR/archive-$(date +%Y-%m).zip"
        zip -j "$archive_name" "${old_files[@]}"
        log "🗜️ Archived ${#old_files[@]} files to $(basename "$archive_name")"

        if [ "$DRY_RUN" = false ]; then
            rm -f -- "${old_files[@]}"
            log "🗑️ Removed archived files"
        fi
    else
        log "ℹ️ No files older than $ARCHIVE_OLDER_DAYS days to archive"
    fi
}

# Run versioning & archiving
backup_klwp_versions
archive_old_versions

# ──────────── 3) Upload versioned files ────────────
log "🦇 Uploading .klwp versions..."
rclone copy \
    "$SRC_DIR/" "$DEST_ONEDRIVE/" \
    --include "*_v*.klwp" "${RCLONE_OPTS[@]}" \
    --log-file="$LOGFILE" --log-level=INFO

# ──────────── 4) Integrity check ────────────
log "🔍 Integrity check of versioned files..."
if ! rclone check \
       "$SRC_DIR" "$DEST_ONEDRIVE" \
       --include "*_v*.klwp" \
       --log-file="$LOGFILE" --log-level=ERROR
then
    log "⚠️ Integrity check detected mismatches!"
fi

# ──────────── 5) Sync everything else ────────────
log "🦇 Syncing other files..."
rclone sync \
    "$SRC_DIR/" "$DEST_ONEDRIVE/" \
    --exclude "*.klwp" --exclude "*_v*.klwp" \
    "${RCLONE_OPTS[@]}" \
    --log-file="$LOGFILE" --log-level=INFO

# ──────────── 6) Post-run notification ────────────
if command -v termux-notification >/dev/null; then
    termux-notification \
      --title "KLWP Backup" \
      --content "Done: kept $VERSIONS_TO_KEEP versions; archived >${ARCHIVE_OLDER_DAYS}d" \
      --priority high
fi

log "✅ KLWP Backup complete!"
