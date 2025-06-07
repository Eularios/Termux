#!/data/data/com.termux/files/usr/bin/bash

# Defina aqui o nome base do arquivo KLWP (sem extensão ou _vN)
BASENAME="$1"
DIR="/storage/emulated/0/Kustom/wallpapers"

if [ -z "$BASENAME" ]; then
    echo "Uso: $0 <nome_base_klwp> (ex: KLWP_THEME_BR)"
    exit 1
fi

# Descobre a última versão local
local_versions=$(ls "$DIR/${BASENAME}"_v*.klwp 2>/dev/null | sort -V)
lastver=$(echo "$local_versions" | sed -E "s/.*_v([0-9]+)\.klwp/\1/" | sort -n | tail -1)

if [ -z "$lastver" ]; then
    echo "Não existe nenhuma versão local para comparar: ${BASENAME}_vN.klwp"
    exit 2
fi

prevfile="$DIR/${BASENAME}_v${lastver}.klwp"
origfile="$DIR/${BASENAME}.klwp"

echo "Comparando $origfile  <===>  $prevfile"

if cmp -s "$origfile" "$prevfile"; then
    echo "🟢 IGUAL: Não mudou!"
else
    echo "🔴 DIFERENTE: Mudou!"
fi
