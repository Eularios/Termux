#!/data/data/com.termux/files/usr/bin/bash

SOURCE="/sdcard/termux_share"
DEST="$HOME/scripts"
LOGFILE="$HOME/scripts/sync.log"

echo " $(date '+%Y-%m-%d %H:%M:%S') — Syncing files from $SOURCE to $DEST..." | tee -a "$LOGFILE"

# Check if source exists
if [ ! -d "$SOURCE" ]; then
    echo " Folder not found: $SOURCE" | tee -a "$LOGFILE"
    exit 1
fi

# Loop through visible files (.)
for file in "$SOURCE"*/*; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        if [[ "$filename" != "sync_from_pc.sh" ]]; then
            cp "$file" "$DEST/$filename"
            chmod +x "$DEST/$filename"
            echo "✅ $(date '+%H:%M:%S') Synced: $filename" | tee -a "$LOGFILE"
        else
            echo "✅ $(date '+%H:%M:%S') Skipped: $filename" | tee -a "$LOGFILE"
        fi
    fi
done
# Loop through hidden files (.*)
for file in "$SOURCE"/.*; do
    if [ -f "$file" ] && [[ "$(basename "$file")" != "." && "$(basename "$file")" != ".." ]]; then
        filename=$(basename "$file")
        cp "$file" "$DEST/$filename"
        chmod +x "$DEST/$filename"
        echo "✅ $(date '+%H:%M:%S') — Synced (hidden): $filename" | tee -a "$LOGFILE"
    fi
done

echo " $(date '+%Y-%m-%d %H:%M:%S') — Sync completed." | tee -a "$LOGFILE"
