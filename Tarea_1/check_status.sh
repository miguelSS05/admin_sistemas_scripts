#!/bin/bash

echo "=== Script Bienvenida ==="

echo -n "Nombre del equipo: "
hostname

echo -n "IP Interna del equipo: "
ip a show red_sistemas | awk '/inet/ {print $2}' | cut -d "/" -f1


# Muestra informacion sobre los sistemas de archivos
# Busca donde esta montado "/" con una expresion regular
# Imprime en pantalla el resultado

df -h | awk '/\/$/ {print "Espacio usado disco: " $3 "B\nEspacio libre disco: " $4 "B"}'