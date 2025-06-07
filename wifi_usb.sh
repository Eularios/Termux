#!/data/data/com.termux/files/usr/bin/sh
su -c "setprop service.adb.tcp.port 5555; stop adbd; start adbd"
ip a | grep wlan0
echo "✅ ADB Wi-Fi ativo! Agora conecte do PC: adb connect 192.168.3.6:5555"
