#!/bin/bash

source ../Funciones/bash_fun.sh --source-only  # Obtener funciones
v[opc]="0" # Inicializar variable con valor "0"

change_conf() {
	echo -e "\n=== IPs Consecionadas ===\n"

	getText "Ingresa el ambito: " scope
	validateIp "Ingresa la IP Inicial: " ip_ini
	validateIp "Ingresa la IP Final: " ip_fin
	validateIp "Ingresa la Puerta de Enlace: " gateway
	getText "Ingresa el DNS: " dns
	validateInt "Ingresa el tiempo de consecion (en segundos): " leasetime

	config="# Descripcion(Ambito): ${v[scope]}"
	config="$config\nsubnet 192.168.100.0 netmask 255.255.255.0 {"
	config="$config\n        range ${v[ip_ini]} ${v[ip_fin]};"
	config="$config\n        option routers ${v[gateway]};"
	config="$config\n        option domain-name-servers ${v[dns]};"
	config="$config\n        default-lease-time ${v[leasetime]};"
	config="$config\n        max-lease-time ${v[leasetime]};"
	config="$config\n}"

	echo -e $config > /etc/dhcp/dhcp.conf
	echo "Se ha editado el archivo de configuracion"
	echo "Reiniciando servicio..."
	systemctl restart isc-dhcp-server

}

leases_dhcp() {
	echo -e "\n=== IPs Consecionadas ===\n"
	cat /var/lib/dhcp/dhcpd.leases | grep -E "lease [0-9]|starts|ends|}"
}

state_dhcp() {
	echo -e "\n=== Estado del servicio ===\n"
	systemctl status isc-dhcp-server | head -n 12
}

check_service() {
	if [ "$(dpkg -l 'isc-dhcp-server' 2>&1 | grep 'ii')" = "" ]; then
		echo "No se ha detectado el servicio isc-dhcp-server"
		echo "Iniciando instalación..."
		apt-get install isc-dhcp-server > /dev/null
		configure_interface
		echo "Se ha terminado de instalar el servicio isc-dhcp-server"
	fi
}

configure_interface() {
	sed 's/INTERFACESv4=""/INTERFACESv4="red_sistemas"/' /etc/default/isc-dhcp-server 
}

check_service

while [ "${v[opc]}" != "4" ]; do
	echo -e "\n=== TAREA 2: Automatizacion / gestion DHCP ===\n"
	echo "[1] Configuración" 
	echo "[2] Consultar estado del servicio" 
	echo "[3] Consultar IPs Alquiladas" 
	echo -e "[4] Salir\n"
	
	validateInt "Elija una opcion: " opc

	case "${v[opc]}" in
		"1")
			change_conf
		;;
		"2")
			state_dhcp
		;;
		"3")
			leases_dhcp
		;;
		"4")
			# Salir
		;;
		*)
			echo -e "\nOpcion invalida\n"
		;;
	esac
done
