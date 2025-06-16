#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

#
# CONFIGURATION
#
SRC_DIR="/storage/emulated/0/Kustom/wallpapers"
DEST_ONEDRIVE="onedrive:/Termux/klwp"
LOGFILE="$HOME/scripts/klwp_backup.log"
VERSIONS_TO_KEEP=3

# Ensure log directory exists
mkdir -p "$(dirname "$LOGFILE")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

# On exit or interrupt
trap 'log "⚠️  Interrupted! Exiting."; exit 1' INT TERM

log ""
log "===== 🦇 Bat-backup KLWP started ====="

backup_klwp_versions() {
    # find all “master” .klwp files (skip already versioned *_vN.klwp)
    mapfile -t masters < <(
        find "$SRC_DIR" -maxdepth 1 -type f -name '*.klwp' \
             ! -name '*_v[0-9]*.klwp' | sort
    )

    if [ ${#masters[@]} -eq 0 ]; then
        log "ℹ️  No .klwp files to version in $SRC_DIR"
        return
    fi

    for filepath in "${masters[@]}"; do
        filename=$(basename "$filepath")
        base="${filename%.klwp}"
        dir="$(dirname "$filepath")"

        # collect existing _v*.klwp versions, sorted by version number
        mapfile -t versions < <(
            find "$dir" -maxdepth 1 -type f -name "${base}_v*.klwp" \
                 | sort -V
        )

        # determine lastver
        if [ ${#versions[@]} -gt 0 ]; then
            last="${versions[-1]}"
            lastver=$(printf '%s\n' "$last" \
                      | sed -E 's/.*_v([0-9]+)\.klwp$/\1/')
        else
            lastver=0
        fi

        # skip if nothing changed
        if [ "$lastver" -gt 0 ] && cmp -s "$filepath" "$dir/${base}_v${lastver}.klwp"; then
            log "🟡 $base unchanged since v$lastver; skipping."
            continue
        fi

        # make new version
        newver=$((lastver + 1))
        newfile="$dir/${base}_v${newver}.klwp"
        cp -- "$filepath" "$newfile"
        log "🟢 Created new version: $(basename "$newfile")"

        # prune old versions, keep only the $VERSIONS_TO_KEEP most recent
        mapfile -t allvers < <(
            find "$dir" -maxdepth 1 -type f -name "${base}_v*.klwp" \
                 | sort -V
        )
        count=${#allvers[@]}
        if [ "$count" -gt "$VERSIONS_TO_KEEP" ]; then
            to_delete=$((count - VERSIONS_TO_KEEP))
            for old in "${allvers[@]:0:to_delete}"; do
                rm -f -- "$old"
                log "🗑️  Deleted old version: $(basename "$old")"
            done
        fi
    done
}

backup_klwp_versions

#
# Push only the versioned .klwp files (incremental)
#
log "🦇 Uploading .klwp versions to OneDrive (incremental)..."
rclone copy \
    "$SRC_DIR/" "$DEST_ONEDRIVE/" \
    --include "*_v*.klwp" \
    --log-file="$LOGFILE" --log-level=INFO

#
# Sync everything else (folders, non-.klwp files)
#
log "🦇 Syncing other files/folders (excl. .klwp)..."
rclone sync \
    "$SRC_DIR/" "$DEST_ONEDRIVE/" \
    --exclude "*.klwp" --exclude "*_v*.klwp" \
    --log-file="$LOGFILE" --log-level=INFO

log "✅ Bat-backup complete: versions and other files are up to date!"
