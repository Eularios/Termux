# Painel info ao abrir
bash ~/scripts/termux_info_painel.sh

# Aliases para os scripts principais
alias termux_backup="bash ~/scripts/termux_backup.sh"
alias termux_restore="bash ~/scripts/termux_restore.sh"
alias termux_sync_cloud="bash ~/scripts/termux_sync_onedrive.sh"
alias ebash='nano ~/.bashrc'
alias rbash='source ~/.bashrc'
alias up='pkg update && pkg upgrade -y'
alias gosync='bash ~/scripts/sync_from_pc.sh'
alias sd='cd ~/storage/shared'
alias dl='cd ~/storage/downloads'
alias doc='cd ~/storage/documents'
alias pic='cd ~/storage/pictures'

echo -e "\e[1;36mUse 'termux_backup' para backup, 'termux_restore' para restaurar, 'termux_sync_cloud' para nuvem, e 'ebash' para editar este arquivo.\e[0m"
