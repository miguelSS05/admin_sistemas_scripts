#!/bin/bash

source ../Funciones/bash_fun_par.sh # Funcion parametros

help="--- Opciones ---\n\n"
help="${help}1) Verificar existencia del servicio\n"
help="${help}2) Instalar servicio\n"
help="${help}3) Monitoreo\n" # Verificar sintaxis y ver estado del servicio
help="${help}4) Agregar zona\n"
help="${help}5) Eliminar zona\n"
help="${help}6) Consultar lista de zonas (dominios)\n"
help="${help}7) Verificar configuración IP\n\n"
help="${help}--- Banderas ---\n\n"
help="${help}-h (mostrar este mensaje)\n"
help="${help}-o (seleccionar opcion)\n"
help="${help}-i (confirmar instalacion)\n"
help="${help}-d (nombre de dominio)\n" # Verificar sintaxis y ver estado del servicio
help="${help}-t (time to live)\n"
help="${help}-s (numero serial)\n"
help="${help}-r (refresh)\n"
help="${help}-n (configurar nueva ip)\n"

nueva_ip=""
install="0"
domain_name=""
ttl=604800
serial=3
refresh=604800
retry=86400
expire=2419200
option=0
confirm="0"

# OBTENER PARAMETROS
while getopts ":i :o: :d: :t: :s: :r: :n: :c :h" flag; do
    case "${flag}" in
        o) option=$OPTARG ;;
        i) install="1" ;; 
        d) domain_name=$OPTARG ;;    # FUNCION PARA VALIDAR DOMINIO
        t) ttl=$OPTARG ;;
        s) serial=$OPTARG ;;
        r) refresh=$OPTARG ;; 
        n) nueva_ip=$OPTARG ;; 
        c) confirm="1" ;; 
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

configure_options() {
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
  fi

  resul="$(check_service 'bind9' | grep 'No se ha detectado el servicio')"

  if ! [ "$resul" = "" ]; then
    echo "No se ha detectado el servicio, regresando al menu"
    return 1
  fi

  ip_local=$(getLocalIp)
  ip_segment="$(getSegment $ip_local)"
  prefix_local=$(getPrefix)

  if [ -f /etc/bind/named.conf.options ]; then
    options="options {\n"
    options="${options}  directory \"/var/cache/bind\";\n"
    options="${options}  dnssec-validation auto;\n"
    options="${options}  listen-on {${ip_segment}/${prefix_local}; localhost; };\n"
    options="${options}  allow-query {{${ip_segment}/${prefix_local}; localhost; };\n"
    options="${options}  recursion yes;\n"
    options="${options}  allow-recursion {{${ip_segment}/${prefix_local}; localhost; };\n"
    options="${options}};"

    echo -e $options > /etc/bind/named.conf.options
  else 
    echo "No se ha encontrado el archivo /etc/bind/named.conf.options"
    return 1
  fi

  if [ -f /etc/default/named ]; then
    sed -i 's/OPTIONS="-u bind"/OPTIONS="-u bind -4"/' /etc/default/named
  else 
    echo "No se ha encontrado el archivo /etc/default/names"
  fi
}

status_service() { # VERIFICAR SI EL SERVICIO ESTA INSTALADO ANTES
	if [ "$(systemctl status named 2>&1 | grep 'could not be found')" = "" ]; then
	  echo -e "\n=== Estado del servicio ===\n"
	  systemctl status named | head -n 12	
	else
		echo -e "\nNo se ha detectado el servicio named"
    exit 1
	fi

  if [ "$(named-checkconf)" = "" ]; then
    echo  "No se han detectado errores de sintaxis"
  else 
    echo "Se detectaron los siguientes errores de sintaxis"
    named-checkconf
  fi
}

configure_service() {
  ip_local=$(getLocalIp)
  resul=$(validateIpConf "$ip_local")
  #ip_segment="$(getSegment $ip_local)"

  if [ "$resul" = "false" ]; then
    if [ "$nueva_ip" = "" ]; then
      echo "Se ha detectado una configuracion de IP invalida"
      echo "Para seleccionar una nueva IP use la bandera -n"
      return 1
    fi
    validateIp "$nueva_ip" "IP Nueva"
    restart_ip "$nueva_ip"
    echo "Se ha modificado la ip"
  fi

	if ! [ "$(systemctl status named 2>&1 | grep 'could not be found')" = "" ]; then
		echo -e "\nNo se ha detectado el servicio named"
    exit 1
	fi

  # VALIDAR VALORES
  validateEmpty "$domain_name" "Nombre de dominio"
  validateInt "$ttl" "Time To Live"
  validateInt "$serial" "Serial"
  validateInt "$refresh" "Refrescar"
  validateInt "$retry" "Tiempo en el cual invalidaria el servicio"
  validateInt "$expire" "Tiempo de expiracion"

  content="" #
  start="^[[:space:]]*zone[[:space:]]*\"$domain_name\"[[:space:]]*{[[:space:]]*"
  end="^[[:space:]]*}[[:space:]]*;[[:space:]]*"
  filedir="^[[:space:]]*file[[:space:]]*\""
  filedb=""

  if [ -n "$(awk '/$start/' /etc/bind/named.conf.local)" ]; then # -n non-zero length (no nulo)
    echo -e "\nSe ha encontrado el dominio(zona) $domain_name"
    if [ "$confirm" = "0" ]; then
      echo -e "Para sobreescribir use la bandera -c (confirmar)\n"
      exit 1
    else
      echo -e "Se ha activado la bandera -c para sobreescribir sus registros DNS\n"
    fi
  else
    cat << EOF >> /etc/bind/named.conf.local #
    
zone "$domain_name" {
  type master;
  file "/var/cache/bind/db.$domain_name";
};

EOF
    # sobreescribir aqui
  fi

  # while read line; do
  #   content="$content$line\n"
  #   if [ "$line" =~ $start ]; then
  #     echo -e "\nSe ha encontrado la zona ya registrada, por lo que se sobreescribira sus registros DNS\n"
      
  #     if [ "$confirm" = "0" ]; then
  #       echo -e "Para sobreescribir use la bandera -c (confirmar)\n"
  #       exit 1
  #     else
  #       echo -e "Se ha activado la bandera -c para sobreescribir sus registros DNS\n"
  #     fi
  #   fi
  # done < /etc/bind/named.conf.local

  # DECIDIR SI SOBREESCRBIR O ESCRIBIR
  # FUNCION BUSCAR
#   cat << EOF > /etc/bind/named.conf.local #

#   zone \"$domain_name\" {
#     type master;
#     file \"/var/cache/bind/db.$domain_name\";
#   };

# EOF

  cat << EOF > /var/cache/bind/db.$domain_name

\$TTL $ttl

@          IN          SOA          ns1.$domain_name. admin.$domain_name. (
                                      $serial;
                                      $refresh;
                                      $retry;
                                      $expire;
                                      $ttl; )
@          IN          NS           ns1.$domain_name.
@          IN          A            $ipLocal
ns1        IN          A            $ipLocal
www        IN          A            $ipLocal

EOF

  echo "Reiniciando servicio..."
  systemctl restart named
}

read_zones() {
  if [ -f /etc/bind/named.conf.local ]; then
    echo -e "\n=== Lista de zonas (dominios) ===\n"
    cat /etc/bind/named.conf.local | awk '/^\s*zone/ {print $2}'
  else
    echo -e "\nNo se ha encontrad el archivo de configuraicon /etc/bind/named.conf.local"
  fi
}

delete_zone() {
  content="" #
  start="^[[:space:]]*zone[[:space:]]*\"$domain_name\"[[:space:]]*{[[:space:]]*"
  end="^[[:space:]]*}[[:space:]]*;[[:space:]]*"
  filedir="^[[:space:]]*file[[:space:]]*\""
  filedb=""

  validateEmpty "$domain_name" "Nombre de dominio"

  if ! [ -f /etc/bind/named.conf.local ]; then
    echo -e "\nNo se ha encontrado el archivo de configuracion /etc/bind/named.conf.local"
    exit 1
  fi

  if [ -z "$(awk '/$start/' /etc/bind/named.conf.local)" ]; then # -z zero length (nulo)
    echo -e "\nNo se ha encontrado el dominio(zona) $domain_name"
    exit 1
  fi

  # Buscar donde tiene guardados los registros
  filedb=$(awk -v start="$start" -v end="$end" '
  $0 ~ start {skip=0}
  $0 ~ end {skip=1; next}
  skip' /etc/bind/named.conf.local | awk '/file/ {print $2}' | cut -d "\"" -f2)

  if [ -f $filedb ] && [ -n $filedb ]; then
      rm $filedb
      cat $filedb
  else
      echo -e "No se encontraron los registros para la zona $domain_name"
  fi

  # Excluir a un dominio en especifico del archivo de zona
  awk -v start="$start" -v end="$end" '
  $0 ~ start {skip=1}
  $0 ~ end {skip=0; next}
  !skip' /etc/bind/named.conf.local > temp.txt && temp.txt > /etc/bind/named.conf.local && rm temp.txt

  # while read line; do
  #   if [ "$line" =~ $start ]; then
  #     echo -e "\nSe ha encontrado la zona\n"
  #     echo -e "$line"

  #     while read line; do
  #       echo -e "$line"
  #       if [ "$line" =~ $end ]; then
  #         break;
  #       fi

  #       if [ "$line" =~ $filedir ]; then
  #         filedb=$($line | awk '/file/ {print $2}' | cut -d "\"" -f2)
  #       fi
  #     done

  #     if [ -f $filedb ]; then
  #       cat $filedb
  #     else
  #       echo -e "No se encontraron los registros para la zona $domain_name"
  #     fi

  #     exit 1
  #   else
  #     content="$content$line\n"
  #   fi
  # done < /etc/bind/named.conf.local
}

#configureIp

case "$option" in
  1) 
  check_service "bind9"
  check_service "bind9-utils"
  check_service "bind9-doc"
  ;; # BUSCAR INSTALAR bind9, bind9-doc, bind9-utils
  2) 
  install_service "bind9" "$install"
  install_service "bind9-utils" "$install"
  install_service "bind9-doc" "$install"
  configure_options 
  ;;
  3) status_service ;;
  4) configure_service ;;
  5) delete_zone ;;
  6) read_zones ;;
  7) configureIp ;;

  *) echo "Opcion invalida" ;;
esac