#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Diagnóstico ──────────────────────────────────────────────────
echo "SCRIPT_DIR: $SCRIPT_DIR"
echo "Buscando bash_fun.sh en: ${SCRIPT_DIR}/../Funciones/bash_fun.sh"

if [[ ! -f "${SCRIPT_DIR}/../Funciones/bash_fun.sh" ]]; then
    echo "❌ ERROR: bash_fun.sh no encontrado"
    exit 1
fi

if [[ ! -f "${SCRIPT_DIR}/http_functions.sh" ]]; then
    echo "❌ ERROR: http_functions.sh no encontrado"
    exit 1
fi
# ── Fin diagnóstico ──────────────────────────────────────────────

source "${SCRIPT_DIR}/../Funciones/bash_fun.sh" || { echo "❌ Error al cargar bash_fun.sh"; exit 1; }
source "${SCRIPT_DIR}/http_functions.sh"        || { echo "❌ Error al cargar http_functions.sh"; exit 1; }

# ══════════════════════════════════════════════════════════════════
# FUNCIONES DE DISPLAY
# ══════════════════════════════════════════════════════════════════

mostrar_menu_servidores_web() {
    clear
    echo -e "\e[36m==============================================\e[0m"
    echo -e "\e[36m       GESTOR DE SERVIDORES WEB (BASH)\e[0m"
    echo -e "\e[36m==============================================\e[0m"
    echo "1) Menú Apache"
    echo "2) Menú Nginx"
    echo "3) Menú Tomcat"
    echo "0) Salir"
    echo -e "\e[36m==============================================\e[0m"
}

mostrar_menu_apache() {
    clear
    echo -e "\e[36m==============================================\e[0m"
    echo -e "\e[36m       SERVIDOR APACHE\e[0m"
    echo -e "\e[36m==============================================\e[0m"
    echo "1) Listar versiones de Apache"
    echo "2) Instalar Apache"
    echo "3) Verificar instalación Apache"
    echo "4) Monitoreo Apache"
    echo "5) Modificar puerto Apache"
    echo "0) Salir"
    echo -e "\e[36m==============================================\e[0m"
}

mostrar_menu_nginx() {
    clear
    echo -e "\e[36m==============================================\e[0m"
    echo -e "\e[36m       SERVIDOR NGINX\e[0m"
    echo -e "\e[36m==============================================\e[0m"
    echo "1) Listar versiones de NGINX"
    echo "2) Instalar NGINX"
    echo "3) Verificar instalación NGINX"
    echo "4) Monitoreo NGINX"
    echo "5) Modificar puerto NGINX"
    echo "0) Salir"
    echo -e "\e[36m==============================================\e[0m"
}

mostrar_menu_tomcat() {
    clear
    echo -e "\e[36m==============================================\e[0m"
    echo -e "\e[36m       SERVIDOR TOMCAT\e[0m"
    echo -e "\e[36m==============================================\e[0m"
    echo "1) Listar versiones de Tomcat"
    echo "2) Instalar Tomcat"
    echo "3) Verificar instalación Tomcat"
    echo "4) Monitoreo Tomcat"
    echo "5) Modificar puerto Tomcat"
    echo "0) Salir"
    echo -e "\e[36m==============================================\e[0m"
}
# ══════════════════════════════════════════════════════════════════
# MENÚ APACHE
# ══════════════════════════════════════════════════════════════════

menu_apache() {
    local opcion=""

    while true; do
        mostrar_menu_apache
        read -rp "Seleccione una opción: " opcion

        case "$opcion" in
            1)
                list_pkg_versions "apache2"
                ;;
            2)
                if buscar_servicio_instalado "apache2"; then
                    echo "Se ha encontrado el servicio instalado"
                    return 1
                fi

                read -rp "Seleccione una versión: " version
                download_pkg "apache2" "$version"

                local ports_conf="/etc/apache2/ports.conf"
                # ── Eliminar Listen 80 por defecto si existe ──────────────────
                if grep -q "^Listen 80$" "$ports_conf"; then
                    sed -i 's/^Listen 80$/# Listen 80/' "$ports_conf"
                    echo "  [✔] Listen 80 por defecto deshabilitado"
                fi
                ;;
            3)
                verificar_instalacion_servicio "apache2"
                ;;
            4)
                obtener_estatus_servicio "apache2"
                ;;
            5)
                read -rp "Seleccione un puerto: " puerto
                configurar_apache "Apache" "$(apache2 -v 2>/dev/null | awk '/version/ {print $3}' | cut -d'/' -f2)" "$puerto"
                ;;
            0)
                echo -e "\e[32mSaliendo del menú Apache...\e[0m"
                sleep 1
                return 0
                ;;
            *)
                echo -e "\e[31mOpción no válida, por favor intente de nuevo.\e[0m"
                sleep 2
                continue
                ;;
        esac

        read -rp $'\nPresione Enter para volver al menú'
    done
}

# ══════════════════════════════════════════════════════════════════
# MENÚ NGINX
# ══════════════════════════════════════════════════════════════════

menu_nginx() {
    local opcion=""

    while true; do
        mostrar_menu_nginx
        read -rp "Seleccione una opción: " opcion

        case "$opcion" in
            1)
                list_pkg_versions "nginx"
                ;;
            2)
                if buscar_servicio_instalado "nginx"; then
                    echo "Se ha encontrado el servicio instalado"
                    return 1
                fi

                read -rp "Seleccione una versión: " version
                download_pkg "nginx" "$version"

                # ── 2. Deshabilitar sitio default (elimina el Listen 80) ──────
                local default_link="/etc/nginx/sites-enabled/default"

                if [[ -L "$default_link" ]]; then
                    rm "$default_link"
                    echo "  [✔] Sitio default deshabilitado (Listen 80 eliminado)"
                fi

                ;;
            3)
                verificar_instalacion_servicio "nginx"
                ;;
            4)
                obtener_estatus_servicio "nginx"
                ;;
            5)
                read -rp "Seleccione un puerto: " puerto
                configurar_nginx "nginx" "$(nginx -v 2>&1 | awk '/version/ {print $3}' | cut -d'/' -f2)" "$puerto"
                ;;
            0)
                echo -e "\e[32mSaliendo del menú Nginx...\e[0m"
                sleep 1
                return 0
                ;;
            *)
                echo -e "\e[31mOpción no válida, por favor intente de nuevo.\e[0m"
                sleep 2
                continue
                ;;
        esac

        read -rp $'\nPresione Enter para volver al menú'
    done
}

menu_tomcat() {
    local opcion=""

    while true; do
        mostrar_menu_tomcat
        read -rp "Seleccione una opción: " opcion

        case "$opcion" in
            1)
                list_pkg_versions "tomcat10"
                ;;
            2)
                if buscar_servicio_instalado "tomcat10"; then
                    echo "Se ha encontrado el servicio instalado"
                    return 1
                fi
                read -rp "Seleccione una versión: " version
                download_pkg "tomcat10" "$version"
                ;;
            3)
                verificar_instalacion_servicio "tomcat10"
                ;;
            4)
                obtener_estatus_servicio "tomcat10"
                ;;
            5)
                    # Detectar versión mayor instalada de Tomcat (9, 10, 11...)
                local tomcat_pkg
                tomcat_pkg=$(dpkg -l 'tomcat*' 2>/dev/null | awk '/^ii/ {print $2}' | grep -P '^tomcat\d+$' | head -1)

                read -rp "Seleccione un puerto: " puerto
                configurar_tomcat "ROOT" "$(dpkg -l "$tomcat_pkg" 2>/dev/null | awk '/^ii/ {print $3}' | head -1)" "$puerto"
                ;;
            0)
                echo -e "\e[32mSaliendo del menú Tomcat...\e[0m"
                sleep 1
                return 0
                ;;
            *)
                echo -e "\e[31mOpción no válida, por favor intente de nuevo.\e[0m"
                sleep 2
                continue
                ;;
        esac

        read -rp $'\nPresione Enter para volver al menú'
    done
}

# ══════════════════════════════════════════════════════════════════
# MENÚ PRINCIPAL
# ══════════════════════════════════════════════════════════════════

opcion=""

while true; do
    mostrar_menu_servidores_web
    read -rp "Seleccione una opción: " opcion

    case "$opcion" in
        1)
            menu_apache
            ;;
        2)
            menu_nginx
            ;;
        3)
            menu_tomcat
            ;;
        0)
            echo -e "\e[32mSaliendo del programa...\e[0m"
            sleep 1
            exit 0
            ;;
        *)
            echo -e "\e[31mOpción no válida, por favor intente de nuevo.\e[0m"
            sleep 2
            continue
            ;;
    esac

    read -rp $'\nPresione Enter para volver al menú'
done