#!/data/data/com.termux/files/usr/bin/bash

echo ""
echo "🧙 Detail Man's Android Tweaker v4.0"
echo "-----------------------------------"
echo "Choose options separated by commas (e.g., 1,3,4)"
echo ""
echo "1) Enable Fullscreen Gestures (FSG NavBar)"
echo "2) Set USB mode to MTP"
echo "3) Enable USB Debugging + Install via USB"
echo "4) Disable all animations (speed boost)"
echo "5) Set screen timeout to 10 minutes"
echo "A) Apply ALL tweaks"
echo "Q) Quit"
echo ""

read -p "Select options: " input

input=$(echo "$input" | tr ',' ' ')

for opt in $input; do
  case "$opt" in
    1)
      su -c "content insert --uri content://settings/global --bind name:s:force_fsg_nav_bar --bind value:s:1"
      echo "✅ FSG NavBar (via content insert)"
     
      ;;
    2)
      su -c "svc usb setFunctions mtp"
      echo "✅ USB set to MTP mode"
      ;;
    3)
      su -c "settings put secure adb_enabled 1"
      su -c "settings put secure install_non_market_apps 1"
      su -c "settings put global verifier_verify_adb_installs 0"
      echo "✅ USB Debugging and Install via USB enabled"
      ;;
    4)
      su -c "settings put global animator_duration_scale 0"
      su -c "settings put global transition_animation_scale 0"
      su -c "settings put global window_animation_scale 0"
      echo "✅ All animations disabled"
      ;;
    5)
      su -c "settings put system screen_off_timeout 600000"
      echo "✅ Screen timeout set to 10 mins"
      ;;
    A|a)
      su -c "settings put global force_fsg_nav_bar 1"
      su -c "svc usb setFunctions mtp"
      su -c "settings put secure adb_enabled 1"
      su -c "settings put secure install_non_market_apps 1"
      su -c "settings put global verifier_verify_adb_installs 0"
      su -c "settings put global animator_duration_scale 0"
      su -c "settings put global transition_animation_scale 0"
      su -c "settings put global window_animation_scale 0"
      su -c "settings put system screen_off_timeout 600000"
      echo "✅ All tweaks applied!"
      ;;
    Q|q)
      echo "👋 Exit requested."
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $opt"
      ;;
  esac
done

