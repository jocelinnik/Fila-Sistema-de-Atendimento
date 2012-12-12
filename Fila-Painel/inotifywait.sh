#!/bin/sh

EVENT=$(inotifywait --format '%e' /home/fila/painel/senhas_chamando.csv)
[ $? != 0 ] && exit
[ "$EVENT" = "MODIFY" ] && cat /home/fila/painel/senhas_chamando.csv
exit 0;
