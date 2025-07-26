# Painel info ao abrir
bash ~/scripts/termux_info_painel.sh

# Aliases para os scripts principais
alias baktmx="bash ~/scripts/termux_backup_sync.sh"
alias ebash='nano ~/.bashrc'
alias rbash='source ~/.bashrc'
alias up='pkg update && pkg upgrade -y'
alias klwp='bash ~/scripts/klwp_backup.sh'
alias sd='cd ~/storage/shared'
alias dl='cd ~/storage/downloads'
alias doc='cd ~/storage/documents'
alias pic='cd ~/storage/pictures'
alias lsklwp='rclone lsl onedrive:/Termux/klwp --max-depth 1 | awk "{ printf \"%10.2f MB  %s\\n\", \$1/1024/1024, \$NF }"'
alias alels='bash ~/scripts/lsdirdt.sh'
alias restmx="bash ~/scripts/restore_termux.sh"
echo -e "\e[1;36mUse 'baktmx' para backup, 'restmx' para restore, 'klwp' para klwpbak, e 'ebash' para editar este arquivo.\e[0m"
