#!/bin/bash

source ../Funciones/bash_fun.sh --source-only  # Obtener funciones
v[opc]="0" # Inicializar variable con valor "0"

change_conf() {
	#v[computerIp]="192.168.10.100"

	#getLocalIp computerIp
	getIpValue computerIp computerIp_val
	getSegment computerIp computerIp_seg

	echo -e "\n=== Configuracion ===\n"

	getText "Ingresa el ambito: " scope
	usableIp "Ingresa la IP Inicial: " ip_ini
	getNetmask "ip_ini" "ip_ini_mask"

	validateIpHosts "ip_ini" "ip_ini_mask"
	if [ "${v[invalidHost]}" = "true" ]; then
		return 1
	fi

	usableIp "Ingresa la IP Final: " ip_fin

	getIpValue "ip_ini" "ip_ini_val"
	getSegment "ip_ini" "ip_ini_seg"

	getIpValue "ip_fin" "ip_fin_val"
	getSegment "ip_fin" "ip_fin_seg"

	if [ ${v[ip_ini_val]} -ge ${v[ip_fin_val]} ]; then
		echo "Se ha detectado que la ip inicial es mayor que la ip final"
		echo "Saliendo..."
		return 1
	fi

	if [ "${v[ip_ini_seg]}" != "${v[ip_fin_seg]}" ]; then
		echo "Se ha detectado que la ip inicial e ip final están en diferente segmento"
		echo "Saliendo..."
		return 1
	fi

	if [ "${v[ip_ini_seg]}" != "${v[computerIp_seg]}" ]; then
		echo "Se ha detectado que el segmento de las IPs no coinciden con la IP estática del servidor DHCP"
		echo "Saliendo..."
		return 1
	fi

	validateIpHosts "ip_fin" "ip_ini_mask"
	if [ "${v[invalidHost]}" = "true" ]; then
		return 1
	fi

	usableIp "Ingresa la Puerta de Enlace: " gateway

	getIpValue "gateway" "gateway_val"
	getSegment "gateway" "gateway_seg"

	getIpValue "computerIp" "computerIp_val"
	getSegment "computerIp" "computerIp_seg"
	

	if [ "${v[ip_fin_seg]}" != "${v[gateway_seg]}" ] || [ "${v[ip_ini_seg]}" != "${v[gateway_seg]}" ]; then
		echo "Se ha detectado que las IPs y la puerta de enlace están en diferente segmento"
		echo "Saliendo..."
		return 1
	fi

	#if [ "$(compareIp gateway ip_ini)" = "true" ] && [ "$(compareIp ip_fin gateway)" = "true" ]; then
	#	echo "Se ha detectado que la puerta de enlace se encuentra en el rango de IPs"
	#	echo "Saliendo..."
	#	return 1
	#fi


	if [ ${v[gateway_val]} -ge ${v[ip_ini_val]} ] && [ ${v[ip_fin_val]} -ge ${v[gateway_val]} ]; then
		echo "Se ha detectado que la puerta de enlace se encuentra en el rango de IPs"
		echo "Saliendo..."
		return 1
	fi

	if [ ${v[ip_ini_val]} -eq ${v[gateway_val]} ] || [ ${v[ip_fin_val]} -eq ${v[gateway_val]} ]; then
		echo "Se ha detectado que la puerta de enlace está entre la ip inicial e ip final"
		echo "Saliendo..."
		return 1
	fi

	validateIpHosts "gateway" "ip_ini_mask"
	if [ "${v[invalidHost]}" = "true" ]; then
		return 1
	fi

	validateRange "ip_ini" "ip_fin" "computerIp" "Se ha detectado que la IP del servidor se encuentra en el rango de asignacion"

	if [ "${v[rangeIp]}" = "false" ]; then
		return 1
	fi

	usableIp "Ingresa el DNS: " dns
	validateInt "Ingresa el tiempo de consecion (en segundos): " leasetime

	config="# Descripcion(Ambito): ${v[scope]}"
	config="$config\nsubnet ${v[ip_ini_seg]} netmask ${v[ip_ini_mask]} {"
	config="$config\n        range ${v[ip_ini]} ${v[ip_fin]};"
	config="$config\n        option routers ${v[gateway]};"
	config="$config\n        option domain-name-servers ${v[dns]};"
	config="$config\n        default-lease-time ${v[leasetime]};"
	config="$config\n        max-lease-time ${v[leasetime]};"
	config="$config\n}"

	echo -e $config > /etc/dhcp/dhcpd.conf
	echo "Se ha editado el archivo de configuracion"
	echo "Reiniciando servicio..."
	systemctl restart isc-dhcp-server

}

monitoreo_dhcp() {
	leases_dhcp
	state_dhcp
}

leases_dhcp() {
	echo -e "\n=== IPs Consecionadas ===\n"
	cat /var/lib/dhcp/dhcpd.leases | grep -E "lease [0-9]|starts|ends|}|hardware"
}

state_dhcp() {
	echo -e "\n=== Estado del servicio ===\n"
	systemctl status isc-dhcp-server | head -n 12
}

install_service() {
	if [ "$(dpkg -l 'isc-dhcp-server' 2>&1 | grep 'ii')" = "" ]; then
		echo "No se ha detectado el servicio isc-dhcp-server"
		getText "¿Desea instalar el servicio? (1/0)" install

		if [ "${v[install]}" = "1" ]; then
			echo "Iniciando instalacion"
			apt-get install isc-dhcp-server > /dev/null
			configure_interface
			echo "Se ha terminado de instalar el servicio isc-dhcp-server"
		elif [ "${v[install]}" = "0" ]; then
			echo "Abortando instalacion"
		else
			echo "Se ha detectado una opc. invalida"		
		fi

		apt-get install isc-dhcp-server > /dev/null
		configure_interface
		echo "Se ha terminado de instalar el servicio isc-dhcp-server"
	else
		echo "Se ha detectado el servicio isc-dhcp-server"
	fi	
}

check_service() {
	if [ "$(dpkg -l 'isc-dhcp-server' 2>&1 | grep 'ii')" = "" ]; then
		echo -e "\nNo se ha detectado el servicio isc-dhcp-server"
	else
		echo -e "\nSe ha detectado el servicio isc-dhcp-server"
	fi
}

configure_interface() {
	sed -i  's/INTERFACESv4=""/INTERFACESv4="red_sistemas"/' /etc/default/isc-dhcp-server 
}

restart_service() {
	echo "Reiniciando servicio..."
	systemctl restart isc-dhcp-server
}

while [ "${v[opc]}" != "6" ]; do
	echo -e "\n=== TAREA 2: Automatizacion / gestion DHCP ===\n"
	echo "[1] Verificar instalacion" 
	echo "[2] Instalar DHCP" 
	echo "[3] Configurar DHCP" 
	echo "[4] Monitoreo" 
	echo "[5] Reiniciar servicio"
	echo -e "[6] Salir\n"
	
	validateInt "Elija una opcion: " opc

	case "${v[opc]}" in
		"1")
			check_service
		;;			
		"2")
			install_service
		;;
		"3")
			change_conf
		;;
		"4")
			monitoreo_dhcp
		;;
		"5")
			restart_service
		;;
		"6")
			# Salir
		;;
		*)
			echo -e "\nOpcion invalida\n"
		;;
	esac
done
