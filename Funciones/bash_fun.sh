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
  local aux=""
  echo -n "$1"
  read aux

  if [ "$3" = "true" ]; then
	if [ "$aux" = "N" ] || [ "$aux" = "n" ]; then
		v[$2]="N"
		return 1
	fi				
  fi

  v[$2]=$(echo $aux |  grep -P '^(((10[0-9])|(1?[1-9]?[0-9])|(2[0-4][0-9])|(25[0-5]))\.){3}((10[0-9])|(1?[1-9]?[0-9])|(2[0-4][0-9])|(25[0-5]))$')

  while [ "${v[$2]}" = "" ]; do
	if [ "$3" = "true" ]; then
		if [ "$aux" = "N" ] || [ "$aux" = "n" ]; then
			v[$2]="N"
			return 1
		fi				
	fi

	echo -e '\nNo se ha detectado el formato IPv4, vuelva a intentarlo'
	echo -n "$1"
        read aux
        v[$2]=$(echo $aux | grep -P '^(((10[0-9])|(1?[1-9]?[0-9])|(2[0-4][0-9])|(25[0-5]))\.){3}((10[0-9])|(1?[1-9]?[0-9])|(2[0-4][0-9])|(25[0-5]))$')
  done 
}

validateInt() { 
  local aux=""
  echo -n "$1"
  read aux

  v[$2]=$(echo $aux | awk '/^[0-9]+$/')

  while [ "${v[$2]}" = "" ]; do
	echo -e '\nNo se ha detectado un numero sin signos (+ | -), vuelva a intentarlo'
        echo -n "$1"
        read aux
        v[$2]=$(echo $aux | awk '/^[0-9]+$/')
  done 
}

banIp() { # NO usar una variable llamada "banIp" por los problemas que pueda causar
	octet1=$(echo $1 | cut -d "." -f1)
	octet2=$(echo $1 | cut -d "." -f2)

	octet1=$((octet1))
	octet2=$((octet2))
		
	v[banIp]=1

	if [ $octet1 -eq 0 ]; then
		echo -e "\nEl primero octeto no puede ser 0"
		return 1
	elif [ $octet1 -eq 127 ]; then
		echo -e "\nEl primero octeto no puede ser 127"
		return 1
	elif [ $octet1 -eq 169 ] && [ $octet2 -eq 254 ]; then
		echo -e "\nLos primeros octetos no pueden ser 169.254"
		return 1
	elif [ $octet1 -ge 224 ]; then
		echo -e "\nSe ha detectado que el primer octeto no pertenece a las clases A/B/C"
		return 1
	fi 

	v[banIp]=0
}

usableIp() {
	validateIp "$1" $2 $3

	if [ "${v[$2]}" = "N" ] || [ "${v[$2]}" = "n" ]; then
		v[$2]=""
		return 1
	fi

	banIp ${v[$2]}

	while [ "${v[banIp]}" = "1" ]; do
		validateIp "$1" $2 $3

		if [ "${v[$2]}" = "N" ] || [ "${v[$2]}" = "n" ]; then
			v[$2]=""
			return 1
		fi

		banIp ${v[$2]}
	done

}

getSegment() {
	octet1=$(echo ${v[$1]} | cut -d "." -f1)
	octet2=$(echo ${v[$1]} | cut -d "." -f2)
	octet3=$(echo ${v[$1]} | cut -d "." -f3)

	octet1=$(($octet1))
	octet2=$(($octet2))
	octet3=$(($octet3))

	if [ $octet1 -ge 1 ] && [ $octet1 -le 126 ]; then
		v[$2]="$octet1.0.0.0"
	elif [ $octet1 -ge 128 ] && [ $octet1 -le 191 ]; then
		v[$2]="$octet1.$octet2.0.0"
	elif [ $octet1 -ge 192 ] && [ $octet1 -le 223 ]; then
		v[$2]="$octet1.$octet2.$octet3.0"
	else
		v[$2]="0.0.0.0"
	fi
}

getNetmask() {
	octet1=$(echo ${v[$1]} | cut -d "." -f1)

	if [ $octet1 -ge 1 ] && [ $octet1 -le 126 ]; then
		v[$2]="255.0.0.0"
	elif [ $octet1 -ge 128 ] && [ $octet1 -le 191 ]; then
		v[$2]="255.255.0.0"
	elif [ $octet1 -ge 192 ] && [ $octet1 -le 223 ]; then
		v[$2]="255.255.255.0"
	fi
}

getIpValue() {
	octet1=$(echo ${v[$1]} | cut -d "." -f1)
	octet2=$(echo ${v[$1]} | cut -d "." -f2)
	octet3=$(echo ${v[$1]} | cut -d "." -f3)
	octet4=$(echo ${v[$1]} | cut -d "." -f4)

	v[$2]=$((octet1*256*256*256 + octet2*256*256 + octet3*256 + octet4))
}

compareIp() {
	getIpValue "$1" $1_val
	getIpValue "$2" $2_val

	if [ "${v[$1_val]}" -gt "${v[$2_val]}" ]; then
		echo "true"
	else
		echo "false"
	fi
}

compareSegment() {
	getSegment $1 "$1_seg"
	getSegment $2 "$2_seg"

	if [ "${v[$1_seg]}" = "${v[$2_seg]}" ]; then
		echo "true"
	else
		echo "false"
	fi	
}

validateRange() {

	if [ "$(compareIp $3 $1)" = "true" ] && [  "$(compareIp "$2" "$3")" = "true" ]; then
		echo $4
		v[rangeIp]="false"
		return
	fi

	if [ "${v[$3]}" = "${v[$1]}" ] || [ "${v[$3]}" = "${v[$2]}" ]; then
		echo $4
		v[rangeIp]="false"
		return
	fi

	v[rangeIp]="true"

}

validateIpHosts() {
	octet1=$(echo ${v[$1]} | cut -d "." -f1)
	octet2=$(echo ${v[$1]} | cut -d "." -f2)
	octet3=$(echo ${v[$1]} | cut -d "." -f3)
	octet4=$(echo ${v[$1]} | cut -d "." -f4)

	octet1=$(($octet1))
	octet2=$(($octet2))
	octet3=$(($octet3))
	octet4=$(($octet4))

	if [ "${v[$2]}" = "255.255.255.0" ]; then
		if [ $octet4 = "0" ]; then
			echo "Se ha detectado que la ip es el primer host (.0), regresando al menu..."
			v[invalidHost]="true"
			return 1
		elif [ $octet4 = "255" ]; then
			echo "Se ha detectado que la ip es es el ultimo host (.255), regresando al menu..."
			v[invalidHost]="true"
			return 1
		fi
	elif [ "${v[$2]}" = "255.255.0.0" ]; then
		if [ $octet4 = "0" ] && [ $octet3 = "0" ]; then
			echo "Se ha detectado que la ip es el primer host (.0.0), regresando al menu..."
			v[invalidHost]="true"
			return 1
		elif [ $octet4 = "255" ] && [ $octet3 = "255" ]; then
			echo "Se ha detectado que la ip es es el ultimo host (.255.255), regresando al menu..."
			v[invalidHost]="true"
			return 1
		fi
	elif [ "${v[$2]}" = "255.0.0.0" ]; then
		if [ $octet4 = "0" ] && [ $octet3 = "0" ] && [ $octet2 = "0" ]; then
			echo "Se ha detectado que la ip es el primer host (.0.0.0), regresando al menu..."
			v[invalidHost]="true"
			return 1
		elif [ $octet4 = "255" ] && [ $octet3 = "255" ] && [ $octet2 = "255" ]; then
			echo "Se ha detectado que la ip es es el ultimo host (.255.255.255), regresando al menu..."
			v[invalidHost]="true"
			return 1
		fi
	fi

	v[invalidHost]="false"
}

getLocalIp() {
	v[$1]=$(ip a show red_sistemas | awk '/inet / {print $2}' | cut -d "/" -f1)
}

sumOne() {
	octet1=$(echo ${v[$1]} | cut -d "." -f1)
	octet2=$(echo ${v[$1]} | cut -d "." -f2)
	octet3=$(echo ${v[$1]} | cut -d "." -f3)
	octet4=$(echo ${v[$1]} | cut -d "." -f4)

	octet4=$((octet4 + 1))

	if [ $octet4 -ge 256 ]; then
		octet4=0
		octet3=$((octet3 + 1))
	fi

	if [ $octet3 -ge 256 ]; then
		octet3=0
		octet2=$((octet2 + 1))
	fi	

	if [ $octet2 -ge 256 ]; then
		octet2=0
		octet1=$((octet1 + 1))
	fi	

	v[$1]="$octet1.$octet2.$octet3.$octet4"		
}


if [ "${1}" != "--source-only" ]; then
	getText "Dame un valor" "var1"
fi

