#!/bin/bash

source ../Funciones/bash_fun_par.sh # Funcion parametros

help="--- Opciones ---\n\n"
help="${help}--- Script SSH---\n\n"
help="${help}1) Verificar instalacion del servicio SSH server\n"
help="${help}2) Instalar el servicio SSH Server\n\n"
help="${help}--- Script Instalacion SO ---\n\n"
help="${help}3) Verificar estatus del SO\n"
help="${help}\n--- Script Gestion DHCP ---\n\n"
help="${help}4) Verificar instalacion del servicio DHCP\n"
help="${help}5) Instalar servicio DHCP\n"
help="${help}6) Configurar servicio DHCP\n"
help="${help}7) Monitoreo servicio DHCP\n"
help="${help}8) Reniciar servicio DHCP\n"
help="${help}\n--- Script Gestion DNS ---\n\n"
help="${help}9) Verificar instalacion del servicio DNS\n"
help="${help}10) Instalar servicio DNS\n"
help="${help}11) Monitorear servicio DNS\n"
help="${help}12) Agregar Zona DNS\n"
help="${help}13) Eliminar Zona DNS\n"
help="${help}14) Consultar Zonas DNS\n\n"
help="${help}--- Banderas ---\n\n"
help="${help}-h (mostrar este mensaje)\n"
help="${help}-o (seleccionar opcion)\n"
help="${help}-i (confirmar instalacion)\n"
help="${help}-d (nombre de dominio)\n"
help="${help}-t (time to live | lease time)\n"
help="${help}-s (numero serial | colocar DNS Primario para el DHCP)\n"
help="${help}-r (refresh | colocar DNS Secundario para el DHCP)\n"
help="${help}-g (puerta de enlace)\n"
help="${help}-n (configurar nueva ip)\n"
help="${help}-v (colocar ip para el dominio DNS | colocar IP del rango inicial DHCP)\n"
help="${help}-b (colocar IP del rango final DHCP)\n"

ip=""
ip_final=""
nueva_ip=""
install="0"
domain_name=""
ttl=604800 # Tiempo por defecto
serial=3
refresh=604800
retry=86400
expire=2419200
option=0
puerta_en=""
confirm="0"

# OBTENER PARAMETROS
while getopts ":i :o: :d: :t: :s: :r: :n: :c :h :v: :b:" flag; do
    case "${flag}" in
        o) option=$OPTARG ;;
        i) install="1" ;; 
        d) domain_name=$OPTARG ;;    # FUNCION PARA VALIDAR DOMINIO
        t) ttl=$OPTARG ;;
        s) serial=$OPTARG ;;
        r) refresh=$OPTARG ;; 
        n) nueva_ip=$OPTARG ;; 
        c) confirm="1" ;; 
        v) ip=$OPTARG ;;
        b) ip_final=$OPTARG ;;
        g) puerta_en=$OPTARG ;;  
        h) 
          echo -e $help 
          exit 1
        ;; 
    esac
done

configureIp() {
  ipLocal=$(getLocalIp)
  resul=$(validateIpConf "$ipLocal")

  if [ "$resul" = "false" ]; then
    if [ "$nueva_ip" = "" ]; then
      echo "Se ha detectado una configuracion de IP invalida"
      echo "Para seleccionar una nueva IP use la bandera -n"
      return 1
    fi
    validateIp "$nueva_ip" "IP Nueva"
    restart_ip "$nueva_ip"
    echo "Se ha modificado la ip"
  else
    echo "Se ha detectado la IP configurada correctamente"
  fi
}

case "$option" in
  1)
  check_service "openssh-server"
  ;;
  2)
  install_service "openssh-server" "$install"

  if [ -f /etc/ssh/sshd_config ]; then
    sed -ir 's/#PermitRootLogin prohibit-password[[:space:]]*/PermitRootLogin yes/' /etc/ssh/sshd_config
  else
    echo "No se ha encontrado el archivo de configuracion /etc/ssh/sshd_config"
  fi

	if [ "$(dpkg -l 'openssh-server' 2>&1 | grep 'ii')" = "" ]; then
		echo -e "\nNo se ha detectado el servicio openssh-server"
	else
		echo -e "\nConfigurando servicio para iniciar con el sistema"
    systemctl enable ssh
    restart_service "ssh"
	fi
  ;;
  3) bash ../Tarea_1/check_status.sh
  ;; # BUSCAR INSTALAR bind9, bind9-doc, bind9-utils
  4) 
  check_service "isc-dhcp-server"
  ;;
  5) 
  if [ "$install" = "1" ]; then
    bash ../Tarea_2/gestion_dhcp_par.sh -o 2 -i -n "$nueva_ip"
  else
    bash ../Tarea_2/gestion_dhcp_par.sh -o 2  -n "$nueva_ip"
  fi
  ;;
  6) 
  if [ "$confirm" = "1" ]; then
  bash ../Tarea_2/gestion_dhcp_par.sh -o 3 -c -s "$ip" -e "$ip_final" -g "$puerta_en" -p "$serial" -q "$refresh" -t "$ttl"
  else
  bash ../Tarea_2/gestion_dhcp_par.sh -o 3 -s "$ip" -e "$ip_final" -g "$puerta_en" -p "$serial" -q "$refresh" -t "$ttl"
  fi
  ;;
  7) 
  bash ../Tarea_2/gestion_dhcp_par.sh -o 4 -n "$nueva_ip" ;;
  8) restart_service "isc-dhcp-server" ;;
  9)
  check_service "bind9"
  check_service "bind9-utils"
  check_service "bind9-doc"
  ;;
  10)
  if [ "$install" = "1" ]; then
  bash ../Tarea_3/gestion_dns.sh -o 2 -i -n "$nueva_ip"
  else
  bash ../Tarea_3/gestion_dns.sh -o 2 -n "$nueva_ip"
  fi
  ;;
  11)
  bash ../Tarea_3/gestion_dns.sh -o 3 -n "$nueva_ip"
  ;;
  12)
  if [ "$confirm" = "1" ]; then
  bash ../Tarea_3/gestion_dns.sh -o 4 -c -d "$domain_name" -v "$ip" -s "$serial" -r "$refresh" -n "$nueva_ip"
  else
  bash ../Tarea_3/gestion_dns.sh -o 4 -d "$domain_name" -v "$ip" -s "$serial" -r "$refresh" -n "$nueva_ip"
  fi
  ;;
  13)
  bash ../Tarea_3/gestion_dns.sh -o 5 -d "$domain_name" -n "$nueva_ip"
  ;;
  14)
  bash ../Tarea_3/gestion_dns.sh -o 6 -n "$nueva_ip"
  ;;

  *) echo "Opcion invalida" ;;
esac