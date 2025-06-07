#!/data/data/com.termux/files/usr/bin/bash

logfile="$HOME/scripts/termux_scripts.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Executado: $0 $@" >> "$logfile"

echo -e "\e[1;36m=== INFO MOBILE TERMUX ===\e[0m"
echo -e "\e[1;33mDevice:\e[0m $(getprop ro.product.model) \e[1;33mAndroid:\e[0m $(getprop ro.build.version.release)"
echo -e "\e[1;34mUser:\e[0m $USER    \e[1;34mHome:\e[0m $HOME"
echo -e "\e[1;32mStorage Used:\e[0m $(df -h ~ | tail -1 | awk '{print $3 " / " $2}')"

# IP só pelo ifconfig
ip_addr=$(ifconfig 2>/dev/null | grep -A1 'wlan0' | awk '/inet /{print $2}' | head -n1)
[ -z "$ip_addr" ] && ip_addr="n/d"
echo -e "\e[1;35mIP:\e[0m $ip_addr"

echo -e "\e[1;36mTime:\e[0m $(date '+%d/%m/%Y %H:%M:%S')"

# Bateria (universal: sudo, sem sudo, termux-api, fallback)
bat_path="/sys/class/power_supply/battery/capacity"
if command -v sudo >/dev/null 2>&1 && sudo cat "$bat_path" >/dev/null 2>&1; then
    bat=$(sudo cat "$bat_path")
    echo -e "🔋 Battery: $bat% (root)"
elif [ -r "$bat_path" ]; then
    bat=$(cat "$bat_path" 2>/dev/null)
    echo -e "🔋 Battery: $bat%"
elif command -v termux-battery-status >/dev/null 2>&1; then
    bat=$(termux-battery-status | grep -o '"percentage": *[0-9]*' | grep -o '[0-9]\+')
    [ -n "$bat" ] && echo -e "🔋 Battery: $bat% (API)" || echo -e "🔋 Battery: n/d"
else
    echo -e "🔋 Battery: n/d (Acesso negado)"
fi
