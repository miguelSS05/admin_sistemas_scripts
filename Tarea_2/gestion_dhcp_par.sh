#!/bin/bash

source ../Funciones/bash_fun_par.sh # Funcion parametros

option=""
install="0"
ip_inicial=""
ip_final=""
puerta_en=""
dns=""
dns2=""
getLocalIp=""
confirm="0"
ambito=""
tiempo=""

while getopts ":i :o: :d: :t: :s: :e: :g: :c :a: :t:" flag; do
    case "${flag}" in
        a) ambito=$OPTARG ;;
        c) confirm="1" ;;
        o) option=$OPTARG ;;
        i) install="1" ;; 
        s) ip_inicial=$OPTARG ;; # IP INICIAL (s - START)
        e) ip_final=$OPTARG ;; # IP FINAL (e - END)
        g) puerta_en=$OPTARG ;; # PUERTA ENLACE (g - GATEWAY)
        p) dns=$OPTARG ;; # DNS PRIMARIA (p - Primaria)
        q) dns2=$OPTARG ;; # DNS SECUNDARIA
				t) tiempo=$OPTARG ;;
        h) 
          echo -e $help 
          exit 1
        ;; 
    esac
done

change_conf() {
	if [ "$(dpkg -l 'isc-dhcp-server' 2>&1 | grep 'ii')" = "" ]; then
		echo -e "\nNo se ha detectado el servicio isc-dhcp-server, regresa al menú para instalarlo"
		return 1
	fi

    computerIp=$(getLocalIp)
    computerIp_seg=$(getSegment $computerIp)

	#getIpValue computerIp computerIp_val

    usableIp "$ip_inicial" "IP Inicial"
    ip_inicial_seg=$(getSegment "$ip_inicial")
    ip_inicial_val=$(getIpValue "$ip_inicial")
    ip_inicial_mask=$(getNetmask "$ip_inicial")
	

	if [ $ip_inicial_seg != $computerIp_seg ]; then
		echo "Se ha detectado que el segmento de las IPs no coinciden con la IP estática del servidor DHCP"

        if [ "$confirm" = "0" ]; then
		    		echo "Para confirmar el cambio use la bandera -c"
            exit 1
        fi

		restart_ip "$ip_inicial"
		ip_inicial_val=$(sumOne ip_ini)
	fi


	usableIp "$ip_final" "IP Final"
  ip_final_seg=$(getSegment "$ip_final")
  ip_final_val=$(getIpValue "$ip_final")

	if [ $ip_ini_val -gt $ip_fin_val ]; then
		echo "Se ha detectado que la ip inicial es mayor que la ip final"
		echo "Saliendo..."
		return 1
	fi

	if [ "$ip_inicial_seg" != "$ip_final_seg" ]; then
		echo "Se ha detectado que la ip inicial e ip final están en diferente segmento"
		echo "Saliendo..."
		return 1
	fi

	usableIp "$puerta_en" "Puerta de enlace" "true"

	if [ "$puerta_en" != "" ]; then
        puerta_en_seg=$(getSegment "$puerta_en")
		if [ "$ip_final_seg" != "$puerta_en_seg" ] || [ "$ip_inicial_seg" != "$puerta_en_seg" ]; then
			echo "Se ha detectado que las IPs y la puerta de enlace están en diferente segmento"
			echo "Saliendo..."
			return 1
		fi
	fi

	usableIp "$dns" "DNS Primario" "true"

	config="# Descripcion(Ambito): $scope"
	config="$config\nsubnet $ip_inicial_seg netmask $ip_inicial_mask {"
	config="$config\n        range $ip_inicial $ip_final;"

	if [ "$dns" != "" ]; then
		config="$config\n        option domain-name-servers $dns"		
	fi

	usableIp "$dns2" "DNS Secundario" "true"

	if [ "$dns2" != "" ]; then
		if [ "$dns" != "" ]; then
			config="$config, $dns2;"
		else
			config="$config\n        option domain-name-servers $dns2;"		
		fi
	
	elif [ "$dns" != "" ]; then
		config="$config;"
	fi

	if [ "$puerta_en" != "" ]; then
		config="$config\n        option routers $puerta_en;"	
	fi

	validateInt "Ingresa el tiempo de consecion (en segundos): " leasetime

	config="$config\n        default-lease-time $tiempo;"
	config="$config\n        max-lease-time $tiempo;"
	config="$config\n}"

	echo -e $config > /etc/dhcp/dhcpd.conf
	echo "Se ha editado el archivo de configuracion"
	echo "Reiniciando servicio..."
	systemctl restart isc-dhcp-server
}

configure_interface() {
	sed -i  's/INTERFACESv4=""/INTERFACESv4="red_sistemas"/' /etc/default/isc-dhcp-server 
}

monitoreo_dhcp() {
	if [ -f /var/lib/dhcp/dhcpd.leases ]; then
		echo -e "\n=== IPs Concesionadas ===\n"
		cat /var/lib/dhcp/dhcpd.leases | grep -E "lease [0-9]|starts|ends|}|hardware"	
	else
		echo -e "\nNo se ha encontrado el directorio de IPs concesionadas"
	fi

	if [ "$(systemctl status isc-dhcp-server 2>&1 | grep 'Unit isc-dhcp-server.service could not be found')" = "" ]; then
	        echo -e "\n=== Estado del servicio ===\n"
	        systemctl status isc-dhcp-server | head -n 12	
	else
		echo -e "\nNo se ha detectado el servicio isc-dhcp-server"
	fi
}

#restart_service() {
#	if [ "$(dpkg -l 'isc-dhcp-server' 2>&1 | grep 'ii')" = "" ]; then
#		echo -e "\nNo se ha detectado el servicio isc-dhcp-server"
#	else
#		echo "Reiniciando servicio..."
#		systemctl restart isc-dhcp-server	
#	fi
#}

case "$option" in
  1) 
  check_service "isc-dhcp-server"
  ;; # BUSCAR INSTALAR bind9, bind9-doc, bind9-utils
  2) 
  install_service "isc-dhcp-server" "$install"
	configure_interface
  ;;
  3) change_conf ;;
  4) 
	monitoreo_dhcp
  ;;
  5) 
	restart_service "isc-dhcp-server"
  ;;
  *) echo "Opcion invalida" ;;
esac