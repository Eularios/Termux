#!/bin/bash
DIR="${1:-$PWD}"
ls -lha --group-directories-first --time-style=long-iso "$DIR" | \
awk 'NR>1 {
    # Detecta diretório pelo primeiro caractere
    if (substr($0,1,1)=="d") cor="\033[1;34m";    # azul para pastas
    else cor="\033[0m";                           # padrão para arquivos
    print cor $6, $7, substr($0, index($0,$8)) "\033[0m"
}'

ls -lha --group-directories-first --time-style=long-iso "$DIR" | \
awk 'NR>1 {
    if (substr($0,1,1)=="d") cor="\033[1;34m";    # azul
    else cor="\033[0;32m";                        # verde para arquivo
    print cor $6, $7, substr($0, index($0,$8)) "\033[0m"
}'