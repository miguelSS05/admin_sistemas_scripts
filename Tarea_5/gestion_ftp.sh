#!/bin/bash

source ../Funciones/bash_fun_par.sh # Funcion parametros

verificar_root

help="--- Opciones ---\n\n"
help="${help}1) Instalar servicio FTP\n"
help="${help}2) Verificar existencia del servicio FTP\n"
help="${help}3) Desinstalar servicio FTP\n"
help="${help}4) Estatus del servicio FTP\n"
help="${help}5) Agregar usuarios\n"
help="${help}6) Cambiar usuarios de grupo\n"
help="${help}--- Banderas ---\n\n"
help="${help}-h (mostrar este mensaje)\n"
help="${help}-o (seleccionar opcion)\n"
help="${help}-i (confirmar instalacion)\n"
help="${help}-n (numero de usuarios a registrar)\n"
help="${help}-u (lista de usuarios separados por una coma | nombre de usuario para cambiarlo de grupo)\n"
help="${help}-p (lista de contraseñas separadas por una coma)\n"
help="${help}-g (grupo al que pertenece separado por comas [1: reprobados | 2: recursadores])\n"

dir="/home"
option=0
install="0"
confirm="0"

no_users=""
names=""
passwords=""
groups=""

# OBTENER PARAMETROS
while getopts ":h :i :o: :n: :u: :p: :g: :c" flag; do
    case "${flag}" in
        h) 
          echo -e $help 
          exit 1
        ;; 
        o) option=$OPTARG ;;
        i) install="1" ;; 
        n) no_users=$OPTARG ;;    # FUNCION PARA VALIDAR DOMINIO
        u) names=$OPTARG ;;
        p) passwords=$OPTARG ;;
        g) groups=$OPTARG ;; 
        c) confirm="1" ;;
    esac
done

# FALTA COLOCAR CHROOT_LOCAL_USER
configure_options() {
	if [ "$(dpkg -l "vsftpd" 2>&1 | grep 'ii')" = "" ]; then
		echo -e "\nNo se ha detectado el servicio $1"
    exit 1
	fi

  if [ -f /etc/vsftpd.conf ]; then
    sed -ir 's/anonymous_enable=NO/anonymous_enable=YES/' /etc/vsftpd.conf
    sed -ir 's/#chroot_local_user=YES/chroot_local_user=YES/' /etc/vsftpd.conf
    sed -ir 's/#write_enable=YES/write_enable=YES/' /etc/vsftpd.conf

    if [ -z "$(cat /etc/vsftpd.conf | grep "local_root=$dir")" ]; then 
      echo -e "\nlocal_root=$dir" >> /etc/vsftpd.conf # directorio defecto para no-anonymous
    fi

    if [ -z "$(cat /etc/vsftpd.conf | grep "anon_root=$dir")" ]; then 
      echo -e "\nanon_root=$dir" >> /etc/vsftpd.conf # directorio defecto para anonymous
    fi

    if [ -z "$(cat /etc/vsftpd.conf | grep "local_umask=002")" ]; then 
      echo -e "local_umask=002" >> /etc/vsftpd.conf # directorio defecto para anonymous
    fi

  else
    echo "No se ha encontrado el archivo de configuracion /etc/vsftpd.conf"
  fi

  # Crear grupos
  if [ -n "$(groupadd recursadores 2>&1 | grep 'already')" ]; then
    echo "Se ha detectado que el grupo recursadores ya ha sido creado"
  fi

  if [ -n "$(groupadd reprobados 2>&1 | grep 'already')" ]; then
    echo "Se ha detectado que el grupo reprobados ya ha sido creado"
  fi

  if [ -d $dir ]; then
    chmod 711 "$dir" # ocultar directorios

    if ! [ -d "$dir/public" ]; then 
      mkdir "$dir/public"
    fi

    chown "root:users" "$dir/public"
    chmod 775 "$dir/public"  # Permisos para la carpeta public
    chmod g+s "$dir/public"

    if ! [ -d "$dir/reprobados" ]; then 
      mkdir "$dir/reprobados"
    fi

    chown "root:reprobados" "$dir/reprobados"
    chmod 770 "$dir/reprobados"
    chmod g+s "$dir/reprobados"

    if ! [ -d "$dir/recursadores" ]; then 
      mkdir "$dir/recursadores"
    fi    

    chown "root:recursadores" "$dir/recursadores"
    chmod 770 "$dir/recursadores"
    chmod g+s "$dir/recursadores"
  else
    echo "No se ha encontrado el directorio  $dir"
    exit 1
  fi

  restart_service "vsftpd"
}

change_groups() {
  validateEmpty "$names"
  validateGroupNumber "$groups"
  
  if [ "$groups" = "1" ]; then
    if [ -n "$(gpasswd -d "$names" "recursadores" 2>&1 | grep 'is not a member')" ]; then #non-zero length
      echo "Se ha detectado que el usuario $names no pertenecia antes al grupo recursadores"
    fi

    usermod $names -G "reprobados"
  elif [ "$groups" = "2" ]; then
    if [ -n "$(gpasswd -d "$names" "reprobados" 2>&1 | grep 'is not a member')" ]; then #non-zero length
      echo "Se ha detectado que el usuario $names no pertenecia antes al grupo reprobados"
    fi

    usermod $names -G "recursadores"
  fi
}

add_users() {
  validateInt "$no_users" "Numero de usuarios"

  IFS=',' read -ra names <<< "$names" # Separar por comas
  IFS=',' read -ra passwords <<< "$passwords"
  IFS=',' read -ra groups <<< "$groups"

  # Verificar que los arreglos no esten vacios
  validateEmptyArray "${names[@]}"
  validateEmptyArray "${passwords[@]}"
  validateEmptyArray "${groups[@]}"

  validateUserExists "${names[@]}" # Verificar que el usuario exista
  validateGroupNumber "${groups[@]}" # Verificar que el grupo sea 1 o 2

  # Verificar que el num de usuarios ingresados coincida
  if [ "${#names[@]}" != "$no_users" ]; then
    echo "Se ha detectado que el numero de nombres no coincide con el numero de usuarios"
    exit 1
  fi

  if [ "${#passwords[@]}" != "$no_users" ]; then
    echo "Se ha detectado que el numero de contraseñas no coincide con el numero de usuarios"
    exit 1
  fi

  if [ "${#groups[@]}" != "$no_users" ]; then
    echo "Se ha detectado que el numero de grupos no coincide con el numero de usuarios"
    exit 1
  fi

  i=0; # contador

  while [ $i -lt $no_users ]; do
    if [ "${groups[$i]}" = "1" ]; then
      if [ -n "$(useradd -m ${names[$i]} -G reprobados,users 2>&1 | grep 'invalid')" ]; then #non-zero length
        echo "Se ha detectado un error al crear el nombre ${names[$1]}, saliendo del programa"
        exit 1
      fi
    elif [ "${groups[$i]}" = "2" ]; then
      if [ -n "$(useradd -m ${names[$i]} -G recursadores,users 2>&1 | grep 'invalid')" ]; then #non-zero length
        echo "Se ha detectado un error al crear el nombre ${names[$1]}, saliendo del programa"
        exit 1
      fi
    fi

    echo "${names[$i]}:${passwords[$i]}" | chpasswd

    ((i++))
  done

  echo "Se ha terminado de agregar usuarios"
}

case "$option" in
  1) 
  install_service "vsftpd" "$install"
  configure_options
  ;; 
  2)
  check_service "vsftpd"
  ;;
  3) uninstall_service "vsftpd" "$confirm";;
  4) 
  status_service_systemctl "vsftpd"
  ;;
  5) 
  add_users
  ;;
  6) change_groups ;;

  *) echo "Opcion invalida" ;;
esac