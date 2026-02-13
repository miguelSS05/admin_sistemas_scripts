#!/bin/bash

source ../Funciones/bash_fun.sh --source-only  # Obtener funciones
v[opc]="0" # Inicializar variable con valor "0"

change_conf() {
	getLocalIp computerIp
	getIpValue computerIp computerIp_val
	getSegment computerIp computerIp_seg

	echo -e "\n=== Configuracion ===\n"

	getText "Ingresa el ambito: " scope
	usableIp "Ingresa la IP Inicial: " ip_ini
	getIpValue "ip_ini" "ip_ini_val"	

	getNetmask "ip_ini" "ip_ini_mask"
	usableIp "Ingresa la IP Final: " ip_fin
	getIpValue "ip_fin" "ip_fin_val"

	getNetmaskCIDR "ip_ini_val" "ip_fin_val" "ip_ini" "ip_fin" "segment" "netmask" "ip_fin_rango"

	validateRange "segment" "ip_fin_rango" "computerIp" "Se ha detectado que la IP del servidor se encuentra en el rango de asignacion"

	if [ "${v[rangeIp]}" = "false" ]; then
		echo "Se ha detectado que el segmento de las IPs no coinciden con la IP estática del servidor DHCP"
		
		v[opc_2]="";
		getText "¿Desea modificar la IP estática del servidor por la IP inicial o cancelar la configuracion?(S/N): " opc_2

		while [ "${v[opc_2]}" != "S" ] && [ "${v[opc_2]}" != "s" ] && [ "${v[opc_2]}" != "N" ] && [ "${v[opc_2]}" != "n" ]; do
			echo -e "\nSe ha seleccionado una opcion invalida"
			getText "¿Desea modificar la IP estática del servidor por la IP inicial o cancelar la configuracion?(S/N): " opc_2
		done

		if [ "${v[opc_2]}" = "N" ] || [ "${v[opc_2]}" = "n" ]; then
			return 1
		fi

		restart_ip ip_ini
		sumOne ip_ini

		#validateIpHosts "ip_ini" "ip_ini_mask"
		#if [ "${v[invalidHost]}" = "true" ]; then
		#	return 1
		#fi
	fi
	#validateIpHosts "ip_ini" "ip_ini_mask"

#	if [ "${v[invalidHost]}" = "true" ]; then
#		return 1
#	fi

#	if [ "${v[ip_ini_seg]}" != "${v[computerIp_seg]}" ]; then
#		echo "Se ha detectado que el segmento de las IPs no coinciden con la IP estática del servidor DHCP"
		
#		v[opc_2]="";
#		getText "¿Desea modificar la IP estática del servidor por la IP inicial o cancelar la configuracion?(S/N): " opc_2

#		while [ "${v[opc_2]}" != "S" ] && [ "${v[opc_2]}" != "s" ] && [ "${v[opc_2]}" != "N" ] && [ "${v[opc_2]}" != "n" ]; do
#			echo -e "\nSe ha seleccionado una opcion invalida"
#			getText "¿Desea modificar la IP estática del servidor por la IP inicial o cancelar la configuracion?(S/N): " opc_2
#		done

#		if [ "${v[opc_2]}" = "N" ] || [ "${v[opc_2]}" = "n" ]; then
#			return 1
#		fi

#		restart_ip ip_ini
#		sumOne ip_ini

#		validateIpHosts "ip_ini" "ip_ini_mask"
#		if [ "${v[invalidHost]}" = "true" ]; then
#			return 1
#		fi
#	fi

#	validateIpHosts "ip_ini" "ip_ini_mask"

#	getSegment "ip_ini" "ip_ini_seg"

#	getSegment "ip_fin" "ip_fin_seg"

	if [ ${v[ip_ini_val]} -gt ${v[ip_fin_val]} ]; then
		echo "Se ha detectado que la ip inicial es mayor que la ip final"
		echo "Saliendo..."
		return 1
	fi

#	if [ "${v[ip_ini_seg]}" != "${v[ip_fin_seg]}" ]; then
#		echo "Se ha detectado que la ip inicial e ip final están en diferente segmento"
#		echo "Saliendo..."
#		return 1
#	fi

#	validateIpHosts "ip_fin" "ip_ini_mask"
#	if [ "${v[invalidHost]}" = "true" ]; then
#		return 1
#	fi

	usableIp "Ingresa la Puerta de Enlace(N para omitir): " gateway "true"

	if [ "${v[gateway]}" != "" ]; then
		getIpValue "gateway" "gateway_val"
		getSegment "gateway" "gateway_seg"

#		if [ "${v[ip_fin_seg]}" != "${v[gateway_seg]}" ] || [ "${v[ip_ini_seg]}" != "${v[gateway_seg]}" ]; then
#			echo "Se ha detectado que las IPs y la puerta de enlace están en diferente segmento"
#			echo "Saliendo..."
#			return 1
#		fi

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

#		validateIpHosts "gateway" "ip_ini_mask"

#		if [ "${v[invalidHost]}" = "true" ]; then
#			return 1
#		fi
	fi

	getIpValue "computerIp" "computerIp_val"
	getSegment "computerIp" "computerIp_seg"
	
	#if [ "$(compareIp gateway ip_ini)" = "true" ] && [ "$(compareIp ip_fin gateway)" = "true" ]; then
	#	echo "Se ha detectado que la puerta de enlace se encuentra en el rango de IPs"
	#	echo "Saliendo..."
	#	return 1
	#fi

	v[dns]=""
	v[dns2]=""

	usableIp "Ingresa el DNS principal (N para omitirlo): " dns "true"

	config="# Descripcion(Ambito): ${v[scope]}"
	config="$config\nsubnet ${v[segment]} netmask ${v[netmask]} {"
	config="$config\n        range ${v[ip_ini]} ${v[ip_fin]};"

	if [ "${v[dns]}" != "" ]; then
		config="$config\n        option domain-name-servers ${v[dns]}"
		usableIp "Ingresa la DNS secundaria (N para omitirlo): " dns2 "true"

		if [ "${v[dns2]}" != "" ]; then
			config="$config, ${[dns2]};"
		else
			config="$config;"
		fi		
	fi

	if [ "${v[gateway]}" != "" ]; then
		config="$config\n        option routers ${v[gateway]};"	
	fi

	validateInt "Ingresa el tiempo de consecion (en segundos): " leasetime

	config="$config\n        default-lease-time ${v[leasetime]};"
	config="$config\n        max-lease-time ${v[leasetime]};"
	config="$config\n}"

	echo -e $config > /etc/dhcp/dhcpd.conf
	echo "Se ha editado el archivo de configuracion"
	echo "Reiniciando servicio..."
	systemctl restart isc-dhcp-server

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

install_service() {
	if [ "$(dpkg -l 'isc-dhcp-server' 2>&1 | grep 'ii')" = "" ]; then
		echo "No se ha detectado el servicio isc-dhcp-server"
		getText "¿Desea instalar el servicio? (1/0): " install

		if [ "${v[install]}" = "1" ]; then
			echo "Iniciando instalacion"
			apt-get install isc-dhcp-server > /dev/null
			configure_interface
			echo "Se ha terminado de instalar el servicio isc-dhcp-server"
			change_conf
		elif [ "${v[install]}" = "0" ]; then
			echo "Abortando instalacion"
		else
			echo "Se ha detectado una opc. invalida"		
		fi
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
	if [ "$(dpkg -l 'isc-dhcp-server' 2>&1 | grep 'ii')" = "" ]; then
		echo -e "\nNo se ha detectado el servicio isc-dhcp-server"
	else
		echo "Reiniciando servicio..."
		systemctl restart isc-dhcp-server	
	fi
}

restart_ip() {
	if [ "$(cat /etc/network/interfaces | grep 'red_sistemas')" = "" ]; then
		new_iface="auto red_sistemas"
		new_iface="$new_iface\n iface red_sistemas inet static"
		new_iface="$new_iface\n address ${v[$1]}"
		echo -e $new_iface >> /etc/network/interfaces
	else
		sed -i -E "s/[[:space:]]*address[[:space:]]+${v[computerIp]}/address ${v[$1]}/g" /etc/network/interfaces
	fi

	echo -e "\nReiniciando servicio de red para aplicar los cambios..."
	systemctl restart networking
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
