@echo off
set SRC=C:\adb\Termux

echo -----------------------------------------
echo  Enviando files de adb/Termux para /sdcard/termux_share no Android...
echo -----------------------------------------

adb shell mkdir -p /sdcard/termux_share

for %%f in ("%SRC%\*") do (
    echo Enviando Arquivos %%~nxf...
    adb push "%%f" /sdcard/termux_share/
)

@REM echo -----------------------------------------
@REM echo  Disparando sync_from_pc.sh no Termux...
@REM echo -----------------------------------------

@REM adb shell am start -a com.termux.RUN_COMMAND ^
@REM   --es com.termux.RUN_COMMAND_PATH '/data/data/com.termux/files/home/sync_from_pc.sh' ^
@REM   --ez com.termux.RUN_COMMAND_BACKGROUND true ^
@REM   -n com.termux/.RunCommandActivity

echo -----------------------------------------
echo  Tudo pronto, Batman! 
echo  Os arquivos já foram sincronizados com o Termux HOME.
echo -----------------------------------------
pause
