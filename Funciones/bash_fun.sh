#!/bin/bash

declare -A v

getText() {
  local aux=""
  echo -n "$1"
  read aux

  aux=$aux | awk '/\S+/'

  while [ "$aux" = "" ]; do
	echo -e "\nSe ha detectado una cadena vacia, vuelva a intentarlo"	
	echo -n "$1"
	read aux
	aux=$aux | awk '/\S+/'
  done

  v[$2]=$aux
}

validateIp() { 
  getText "$1" $2
  local aux="${v[$2]}"

# Mediante una expresión regular valida un formato IPv4, en caso de no cumplir, se obtiene un espacio vacío.
  v[$2]=$(echo $aux |  grep -P '^(((10[0-9])|(1?[1-9]?[0-9])|(2[0-4][0-9])|(25[0-5]))\.){3}((10[0-9])|(1?[1-9]?[0-9])|(2[0-4][0-9])|(25[0-5]))$')

  while [ "${v[$2]}" = "" ]; do
	echo -e '\nNo se ha detectado el formato IPv4, vuelva a intentarlo'
        getText "$1" $2
        aux="${v[$2]}"
        v[$2]=$(echo $aux | grep -P '^(((10[0-9])|(1?[1-9]?[0-9])|(2[0-4][0-9])|(25[0-5]))\.){3}((10[0-9])|(1?[1-9]?[0-9])|(2[0-4][0-9])|(25[0-5]))$')
  done 
}

validateInt() { 
  getText "$1" $2
  local aux="${v[$2]}"

  v[$2]=$(echo $aux | awk '/^[0-9]+$/')

  while [ "${v[$2]}" = "" ]; do
	echo -e '\nNo se ha detectado un numero sin signos (+ | -), vuelva a intentarlo'
        getText "$1" $2
        aux="${v[$2]}"
        v[$2]=$(echo $aux | awk '/^[0-9]+$/')
  done 
}


export -f validateInt
export -f getText
export -f validateIp

if [ "${1}" != "--source-only" ]; then
	getText "Dame un valor" "var1"
fi
