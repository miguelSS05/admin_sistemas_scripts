#!/bin/bash

formar_plantilla() {
    local nombre="$1"
    local version="$2"
    local puerto="$3"

    # Validar argumentos
    if [[ -z "$nombre" || -z "$version" || -z "$puerto" ]]; then
        echo "Uso: formar_plantilla <nombre> <version> <puerto>" >&2
        echo "Ejemplo: formar_plantilla mi-servicio 1.0.0 8080" >&2
        return 1
    fi

    # Validar que puerto sea numérico
    if ! [[ "$puerto" =~ ^[0-9]+$ ]]; then
        echo "Error: el puerto debe ser un número entero." >&2
        return 1
    fi

    cat <<EOF
<!DOCTYPE html>
<html>
  <head>
    <title>Estatus Servicio</title>
  </head>
  <body>
    <div class='info'>
      <p>Nombre del servicio: ${nombre}</p>
      <p>Version: ${version}</p>
      <p>Puerto: ${puerto}</p>
    </div>
  </body>
  <style>

    body {
      text-align: center;
    }

    p {
      font-size: 24px;
    }

    .info {
      text-align: left;
      width: 40vw;
      height: 40vh;
      display: inline-block;
      background: rgb(240,230,220);
      margin-top: 48px;
      border-radius: 8px;
      border: 2px solid black;
      padding: 8px;
    }

  </style>
</html>
EOF
}
configurar_apache() {
    local nombre="$1"
    local version="$2"
    local puerto="$3"

    # ── Validaciones ──────────────────────────────────────────────
    if [[ -z "$nombre" || -z "$version" || -z "$puerto" ]]; then
        echo "Uso: configurar_apache <nombre> <version> <puerto>" >&2
        echo "Ejemplo: configurar_apache mi-app 1.0.0 8080" >&2
        return 1
    fi


    if ! validar_puerto "$puerto"; then
        return 1
    fi

    #if ! [[ "$puerto" =~ ^[0-9]+$ ]] || (( puerto < 1 || puerto > 65535 )); then
    #    echo "Error: el puerto debe ser un número entre 1 y 65535." >&2
    #    return 1
    #fi

    if ! command -v apache2 &>/dev/null; then
        echo "Error: Apache2 no está instalado." >&2
        return 1
    fi

    if [[ "$EUID" -ne 0 ]]; then
        echo "Error: esta función requiere privilegios de superusuario." >&2
        return 1
    fi

    local sites_available="/etc/apache2/sites-available"
    local ports_conf="/etc/apache2/ports.conf"
    local security_conf="/etc/apache2/conf-available/security.conf"
    local site_conf="${sites_available}/${nombre}.conf"
    local web_root="/var/www/${nombre}"
    local log_dir="/var/log/apache2"
    local listen_tag="# sitio:${nombre}"

    echo "Configurando Apache2 para '${nombre}' v${version} en puerto ${puerto}..."
    echo "────────────────────────────────────────────────────────"

    # ── 1. Gestionar puerto en ports.conf + firewall ──────────────
    if grep -q "$listen_tag" "$ports_conf"; then
        local puerto_actual
        puerto_actual=$(grep -A1 "$listen_tag" "$ports_conf" \
            | tail -1 \
            | awk '{print $2}')

        if [[ "$puerto_actual" == "$puerto" ]]; then
            echo "  [~] Puerto ${puerto} ya estaba configurado para '${nombre}'"
        else
            # ── Eliminar regla del firewall del puerto anterior ────
            echo "  Puerto anterior detectado: ${puerto_actual} → intentando eliminar regla UFW..."
            _eliminar_regla_ufw "$puerto_actual"

            # ── Actualizar puerto existente ───────────────────────────────
            sed -i "/${listen_tag}/{n; s/^Listen .*/Listen ${puerto}/}" "$ports_conf"
            echo "  [✔] Puerto actualizado: ${puerto_actual} → ${puerto} para '${nombre}'"

            # ── Agregar regla del firewall para el nuevo puerto ────
            _agregar_regla_ufw "$puerto"
        fi
    else
# ── Agregar nuevo puerto ──────────────────────────────────────
printf "%s\nListen %s\n" "$listen_tag" "$puerto" >> "$ports_conf"
echo "  [✔] Puerto ${puerto} agregado para '${nombre}'"
        echo "  [✔] Puerto ${puerto} agregado para '${nombre}'"

        # ── Agregar regla del firewall para el nuevo puerto ────────
        _agregar_regla_ufw "$puerto"
    fi

    # ── Agregar ServerName global si no existe ────────────────────
    local apache2_conf="/etc/apache2/apache2.conf"

    if ! grep -q "^ServerName" "$apache2_conf"; then
        echo "ServerName localhost" >> "$apache2_conf"
        echo "  [✔] ServerName global agregado en apache2.conf"
    else
        echo "  [~] ServerName ya estaba definido en apache2.conf"
    fi

    # ── 2. Crear directorio raíz del sitio ────────────────────────
    if [[ ! -d "$web_root" ]]; then
        mkdir -p "$web_root"
        echo "  [✔] Directorio creado: ${web_root}"
    else
        echo "  [~] Directorio ya existe: ${web_root}"
    fi

    # ── 3. Generar página de estado ───────────────────────────────
    if declare -f formar_plantilla &>/dev/null; then
        formar_plantilla "$nombre" "$version" "$puerto" > "${web_root}/index.html"
        echo "  [✔] index.html generado con formar_plantilla"
    else
        cat > "${web_root}/index.html" <<HTML
<!DOCTYPE html>
<html>
  <head><title>${nombre}</title></head>
  <body>
    <h1>${nombre} — v${version}</h1>
    <p>Puerto: ${puerto}</p>
  </body>
</html>
HTML
        echo "  [~] index.html generado (fallback)"
    fi

    chown -R www-data:www-data "$web_root"
    chmod -R 755 "$web_root"
    echo "  [✔] Permisos aplicados en ${web_root}"

    # ── 4. Habilitar módulos necesarios ───────────────────────────
    local mods=("headers" "rewrite" "security2")
    for mod in "${mods[@]}"; do
        if a2enmod "$mod" &>/dev/null; then
            echo "  [✔] Módulo habilitado: ${mod}"
        else
            echo "  [~] Módulo ya estaba activo: ${mod}"
        fi
    done

    # ── 5. Encabezados de seguridad globales ──────────────────────
    cat > "$security_conf" <<SECONF
# ── Ocultar información del servidor ──────────────────────────
ServerTokens Prod
ServerSignature Off

# ── Encabezados de seguridad globales ─────────────────────────
<IfModule mod_headers.c>
    Header unset Server
    Header always unset X-Powered-By
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set Permissions-Policy "geolocation=(), microphone=(), camera=()"
</IfModule>
SECONF

    a2enconf security &>/dev/null
    echo "  [✔] Encabezados de seguridad configurados"

    # ── 6. Crear VirtualHost ──────────────────────────────────────
    cat > "$site_conf" <<VHOST
<VirtualHost *:${puerto}>
    ServerName ${nombre}
    DocumentRoot ${web_root}

    <Directory "${web_root}">
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog  ${log_dir}/${nombre}-error.log
    CustomLog ${log_dir}/${nombre}-access.log combined
</VirtualHost>
VHOST
    echo "  [✔] VirtualHost creado: ${site_conf}"

    # ── 7. Habilitar el sitio ─────────────────────────────────────
    if a2ensite "${nombre}.conf" &>/dev/null; then
        echo "  [✔] Sitio habilitado: ${nombre}"
    else
        echo "  [✘] Error al habilitar el sitio." >&2
        return 1
    fi

    # ── 8. Validar y recargar ─────────────────────────────────────
    echo "────────────────────────────────────────────────────────"
    if apache2ctl configtest 2>&1 | grep -q "Syntax OK"; then
        echo "  [✔] Sintaxis correcta"
    else
        apache2ctl configtest >&2
        return 1
    fi

    if systemctl reload apache2; then
        echo "  [✔] Apache recargado exitosamente"
    else
        echo "  [✘] Error al recargar Apache." >&2
        return 1
    fi

    echo "────────────────────────────────────────────────────────"
    echo "✔ Servicio '${nombre}' configurado y activo"
    echo "  URL         : http://localhost:${puerto}"
    echo "  Web root    : ${web_root}"
    echo "  VirtualHost : ${site_conf}"
    echo "  Logs        : ${log_dir}/${nombre}-{access,error}.log"

    return 0
}

# ── Helpers UFW ───────────────────────────────────────────────────
# Se definen como funciones separadas con _ para indicar uso interno

_agregar_regla_ufw() {
    local puerto="$1"

    if ! command -v ufw &>/dev/null; then
        echo "  [!] UFW no está instalado, omitiendo regla de firewall"
        return 0
    fi

    if ufw status | grep -qw "$puerto"; then
        echo "  [~] Regla UFW ya existe para el puerto ${puerto}"
        return 0
    fi

    if ufw allow "$puerto" &>/dev/null; then
        echo "  [✔] Regla UFW agregada: allow ${puerto}"
    else
        echo "  [!] No se pudo agregar la regla UFW para el puerto ${puerto}" >&2
    fi
}

_eliminar_regla_ufw() {
    local puerto="$1"

    if ! command -v ufw &>/dev/null; then
        echo "  [!] UFW no está instalado, omitiendo eliminación de regla"
        return 0
    fi

    if ! ufw status | grep -qw "$puerto"; then
        echo "  [~] No existe regla UFW para el puerto ${puerto}, nada que eliminar"
        return 0
    fi

    # Obtener números de regla que coincidan con el puerto
    # ufw status numbered devuelve líneas como: [ 3] 8080  ALLOW IN  Anywhere
    #                                            [ 4] 8080 (v6) ALLOW IN  Anywhere (v6)
    local numeros
    numeros=$(ufw status numbered \
        | grep -w "$puerto" \
        | grep -oP '(?<=\[)\s*\d+(?=\])' \
        | tr -d ' ')

    if [[ -z "$numeros" ]]; then
        echo "  [~] No se encontraron reglas numeradas para el puerto ${puerto}"
        return 0
    fi

    # Ordenar de MAYOR a MENOR para evitar que al eliminar un número
    # menor los índices superiores se desplacen y apunten a la regla incorrecta
    local numeros_ordenados
    numeros_ordenados=$(echo "$numeros" | sort -rn)

    echo "  Reglas encontradas para puerto ${puerto}: $(echo $numeros_ordenados | tr '\n' ' ')"

    local eliminadas=0
    local errores=0

    while IFS= read -r num; do
        [[ -z "$num" ]] && continue

        # "yes" confirma automáticamente el prompt interactivo de ufw
        if yes | ufw delete "$num" &>/dev/null; then
            echo "  [✔] Regla #${num} eliminada"
            (( eliminadas++ ))
        else
            echo "  [!] No se pudo eliminar la regla #${num}" >&2
            (( errores++ ))
        fi
    done <<< "$numeros_ordenados"

    if (( errores == 0 )); then
        echo "  [✔] ${eliminadas} regla(s) UFW eliminadas para el puerto ${puerto}"
    else
        echo "  [!] ${eliminadas} eliminada(s), ${errores} con error para el puerto ${puerto}" >&2
    fi
}

configurar_nginx() {
    local nombre="$1"
    local version="$2"
    local puerto="$3"

    # ── Validaciones ──────────────────────────────────────────────
    if [[ -z "$nombre" || -z "$version" || -z "$puerto" ]]; then
        echo "Uso: configurar_nginx <nombre> <version> <puerto>" >&2
        echo "Ejemplo: configurar_nginx mi-app 1.0.0 8080" >&2
        return 1
    fi

    if ! validar_puerto "$puerto"; then
        return 1
    fi

    #if ! [[ "$puerto" =~ ^[0-9]+$ ]] || (( puerto < 1 || puerto > 65535 )); then
    #    echo "Error: el puerto debe ser un número entre 1 y 65535." >&2
    #    return 1
    #fi

    if ! command -v nginx &>/dev/null; then
        echo "Error: Nginx no está instalado." >&2
        echo "Tip: sudo apt-get install nginx" >&2
        return 1
    fi

    if [[ "$EUID" -ne 0 ]]; then
        echo "Error: esta función requiere privilegios de superusuario." >&2
        return 1
    fi

    local sites_available="/etc/nginx/sites-available"
    local sites_enabled="/etc/nginx/sites-enabled"
    local nginx_conf="/etc/nginx/nginx.conf"
    local site_conf="${sites_available}/${nombre}.conf"
    local web_root="/var/www/${nombre}"
    local log_dir="/var/log/nginx"
    local listen_tag="# sitio:${nombre}"

    echo "Configurando Nginx para '${nombre}' v${version} en puerto ${puerto}..."
    echo "────────────────────────────────────────────────────────"

    # ── 1. Gestionar puerto + firewall ────────────────────────────
    #
    # A diferencia de Apache, Nginx no usa ports.conf — el puerto
    # se declara directamente en cada bloque server{} del site conf.
    # Aun así se lleva registro en un archivo propio para poder
    # detectar cambios de puerto entre reconfiguraciones.
    #
    local ports_registro="/etc/nginx/ports-registro.conf"

    # Crear el archivo de registro si no existe
    [[ ! -f "$ports_registro" ]] && touch "$ports_registro"

    if grep -q "$listen_tag" "$ports_registro"; then
        local puerto_actual
        puerto_actual=$(grep -A1 "$listen_tag" "$ports_registro" | tail -1 | awk '{print $1}')

        if [[ "$puerto_actual" == "$puerto" ]]; then
            echo "  [~] Puerto ${puerto} ya estaba configurado para '${nombre}'"
        else
            # Eliminar regla UFW del puerto anterior
            echo "  Puerto anterior detectado: ${puerto_actual} → eliminando regla UFW..."
            _eliminar_regla_ufw "$puerto_actual"

            # Actualizar registro
            sed -i "/${listen_tag}/{n; s/^.*/${puerto}/}" "$ports_registro"
            echo "  [✔] Puerto actualizado: ${puerto_actual} → ${puerto} para '${nombre}'"

            # Agregar regla UFW para el nuevo puerto
            _agregar_regla_ufw "$puerto"
        fi
    else
        printf "%s\n%s\n" "$listen_tag" "$puerto" >> "$ports_registro"
        echo "  [✔] Puerto ${puerto} registrado para '${nombre}'"
        _agregar_regla_ufw "$puerto"
    fi

    # ── 2. Crear directorio raíz del sitio ────────────────────────
    if [[ ! -d "$web_root" ]]; then
        mkdir -p "$web_root"
        echo "  [✔] Directorio creado: ${web_root}"
    else
        echo "  [~] Directorio ya existe: ${web_root}"
    fi

    # ── 3. Generar página de estado ───────────────────────────────
    if declare -f formar_plantilla &>/dev/null; then
        formar_plantilla "$nombre" "$version" "$puerto" > "${web_root}/index.html"
        echo "  [✔] index.html generado con formar_plantilla"
    else
        cat > "${web_root}/index.html" <<HTML
<!DOCTYPE html>
<html>
  <head><title>${nombre}</title></head>
  <body>
    <h1>${nombre} — v${version}</h1>
    <p>Puerto: ${puerto}</p>
  </body>
</html>
HTML
        echo "  [~] index.html generado (fallback)"
    fi

    chown -R www-data:www-data "$web_root"
    chmod -R 755 "$web_root"
    echo "  [✔] Permisos aplicados en ${web_root}"

    # ── 4. Ocultar versión de Nginx en nginx.conf ─────────────────
    #
    # server_tokens off → elimina la versión del header "Server: nginx/x.x.x"
    #                     dejándolo solo como "Server: nginx"
    #
    if ! grep -q "server_tokens off" "$nginx_conf"; then
        sed -i '/http {/a\\tserver_tokens off;' "$nginx_conf"
        echo "  [✔] server_tokens off aplicado en nginx.conf"
    else
        echo "  [~] server_tokens off ya estaba en nginx.conf"
    fi

    # ── 5. Crear bloque server (VirtualHost equivalente) ──────────
    cat > "$site_conf" <<NGINXCONF
server {
    listen ${puerto};
    server_name ${nombre};
    root ${web_root};
    index index.html;

    # ── Encabezados de seguridad ──────────────────────────────
    add_header X-Content-Type-Options  "nosniff"                          always;
    add_header X-XSS-Protection        "1; mode=block"                   always;
    add_header X-Frame-Options         "SAMEORIGIN"                      always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header Referrer-Policy         "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy      "geolocation=(), microphone=(), camera=()" always;

    # Eliminar header Server por completo (requiere módulo headers-more)
    # more_clear_headers Server;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Denegar acceso a archivos ocultos (.env, .git, etc.)
    location ~ /\. {
        deny all;
    }

    error_log  ${log_dir}/${nombre}-error.log;
    access_log ${log_dir}/${nombre}-access.log;
}
NGINXCONF
    echo "  [✔] Bloque server creado: ${site_conf}"

    # ── 6. Habilitar el sitio ─────────────────────────────────────
    # En Nginx se habilita creando un symlink en sites-enabled
    local link="${sites_enabled}/${nombre}.conf"

    if [[ ! -L "$link" ]]; then
        ln -s "$site_conf" "$link"
        echo "  [✔] Sitio habilitado: ${link}"
    else
        echo "  [~] Symlink ya existía: ${link}"
    fi

    # ── 7. Deshabilitar sitio default si ocupa el mismo puerto ────
    local default_link="${sites_enabled}/default"
    if [[ -L "$default_link" ]]; then
        if grep -q "listen ${puerto}" "${sites_available}/default" 2>/dev/null; then
            rm "$default_link"
            echo "  [✔] Sitio default deshabilitado (conflicto en puerto ${puerto})"
        fi
    fi

    # ── 8. Validar y recargar ─────────────────────────────────────
    echo "────────────────────────────────────────────────────────"
    echo "Validando configuración..."

    if nginx -t 2>&1 | grep -q "syntax is ok"; then
        echo "  [✔] Sintaxis correcta"
    else
        nginx -t >&2
        return 1
    fi

    if systemctl reload nginx; then
        echo "  [✔] Nginx recargado exitosamente"
    else
        echo "  [✘] Error al recargar Nginx." >&2
        return 1
    fi

    echo "────────────────────────────────────────────────────────"
    echo "✔ Servicio '${nombre}' configurado y activo"
    echo "  URL         : http://localhost:${puerto}"
    echo "  Web root    : ${web_root}"
    echo "  Site conf   : ${site_conf}"
    echo "  Logs        : ${log_dir}/${nombre}-{access,error}.log"

    return 0
}

configurar_tomcat() {
    local nombre="$1"
    local version="$2"
    local puerto="$3"

    # ── Validaciones ──────────────────────────────────────────────
    if [[ -z "$nombre" || -z "$version" || -z "$puerto" ]]; then
        echo "Uso: configurar_tomcat <nombre> <version> <puerto>" >&2
        echo "Ejemplo: configurar_tomcat mi-app 1.0.0 8080" >&2
        return 1
    fi

    if ! validar_puerto "$puerto"; then
        return 1
    fi

    #if ! [[ "$puerto" =~ ^[0-9]+$ ]] || (( puerto < 1 || puerto > 65535 )); then
    #    echo "Error: el puerto debe ser un número entre 1 y 65535." >&2
    #    return 1
    #fi

    # Detectar versión mayor instalada de Tomcat (9, 10, 11...)
    local tomcat_pkg
    tomcat_pkg=$(dpkg -l 'tomcat*' 2>/dev/null | awk '/^ii/ {print $2}' | grep -P '^tomcat\d+$' | head -1)

    if [[ -z "$tomcat_pkg" ]]; then
        echo "Error: Tomcat no está instalado." >&2
        echo "Tip: sudo apt-get install tomcat10" >&2
        return 1
    fi

    if [[ "$EUID" -ne 0 ]]; then
        echo "Error: esta función requiere privilegios de superusuario." >&2
        return 1
    fi

    # Derivar rutas según el paquete detectado (tomcat9, tomcat10...)
    local tomcat_home="/etc/${tomcat_pkg}"
    local server_xml="${tomcat_home}/server.xml"
    local web_root="/var/lib/${tomcat_pkg}/webapps/${nombre}"
    local log_dir="/var/log/${tomcat_pkg}"
    local ports_registro="/etc/${tomcat_pkg}/ports-registro.conf"
    local listen_tag="# sitio:${nombre}"

    echo "Configurando ${tomcat_pkg} para '${nombre}' v${version} en puerto ${puerto}..."
    echo "────────────────────────────────────────────────────────"

    # ── 1. Gestionar puerto en server.xml + firewall ──────────────
    #
    # En Tomcat el puerto se define en server.xml dentro del conector HTTP:
    # <Connector port="8080" protocol="HTTP/1.1" ... />
    # Se lleva registro en ports-registro.conf igual que en Nginx
    #
    [[ ! -f "$ports_registro" ]] && touch "$ports_registro"

    if grep -q "$listen_tag" "$ports_registro"; then
        local puerto_actual
        puerto_actual=$(grep -A1 "$listen_tag" "$ports_registro" | tail -1 | awk '{print $1}')

        if [[ "$puerto_actual" == "$puerto" ]]; then
            echo "  [~] Puerto ${puerto} ya estaba configurado para '${nombre}'"
        else
            echo "  Puerto anterior detectado: ${puerto_actual} → eliminando regla UFW..."
            _eliminar_regla_ufw "$puerto_actual"

            sed -i "/${listen_tag}/{n; s/^.*/${puerto}/}" "$ports_registro"
            echo "  [✔] Puerto actualizado en registro: ${puerto_actual} → ${puerto}"

            _agregar_regla_ufw "$puerto"
        fi
    else
        printf "%s\n%s\n" "$listen_tag" "$puerto" >> "$ports_registro"
        echo "  [✔] Puerto ${puerto} registrado para '${nombre}'"
        _agregar_regla_ufw "$puerto"
    fi

    local webapps="/var/lib/${tomcat_pkg}/webapps"

    # ── 2. Eliminar aplicaciones por defecto ──────────────────────
    local apps_default=("ROOT" "docs" "examples" "host-manager" "manager")

    for app in "${apps_default[@]}"; do
        if [[ -d "${webapps}/${app}" ]]; then
            rm -rf "${webapps:?}/${app}"
            echo "  [✔] Aplicación por defecto eliminada: ${app}"
        fi
    done

    # ── 2. Modificar puerto del Connector HTTP en server.xml ──────
    #
    # Tomcat usa un único Connector HTTP principal en server.xml.
    # Se reemplaza el puerto del conector existente por el solicitado.
    # Si no existe ningún Connector HTTP se agrega uno nuevo.
    #
    if grep -q 'protocol="HTTP/1.1"' "$server_xml"; then
        sed -i 's/\(<Connector port="\)[^"]*\(" protocol="HTTP\/1.1"\)/\1'"${puerto}"'\2/' "$server_xml"
        echo "  [✔] Puerto del Connector HTTP actualizado a ${puerto} en server.xml"
    else
        # Insertar Connector justo antes del cierre </Service>
        sed -i "/<\/Service>/i\\    <Connector port=\"${puerto}\" protocol=\"HTTP/1.1\" connectionTimeout=\"20000\" redirectPort=\"8443\" />" "$server_xml"
        echo "  [✔] Connector HTTP agregado en puerto ${puerto} en server.xml"
    fi

    # ── 3. Crear directorio de la aplicación web ──────────────────
    local web_inf="${web_root}/WEB-INF"

    if [[ ! -d "$web_inf" ]]; then
        mkdir -p "$web_inf"
        echo "  [✔] Directorio creado: ${web_root}"
    else
        echo "  [~] Directorio ya existe: ${web_root}"
    fi

    # ── 4. Generar página de estado ───────────────────────────────
    if declare -f formar_plantilla &>/dev/null; then
        formar_plantilla "tomcat" "$version" "$puerto" > "${web_root}/index.html"
        echo "  [✔] index.html generado con formar_plantilla"
    else
        cat > "${web_root}/index.html" <<HTML
<!DOCTYPE html>
<html>
  <head><title>tomcat</title></head>
  <body>
    <h1>tomcat — v${version}</h1>
    <p>Puerto: ${puerto}</p>
  </body>
</html>
HTML
        echo "  [~] index.html generado (fallback)"
    fi

    # ── 5. Crear web.xml mínimo para que Tomcat reconozca la app ──
    cat > "${web_inf}/web.xml" <<WEBXML
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="https://jakarta.ee/xml/ns/jakartaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee
                             https://jakarta.ee/xml/ns/jakartaee/web-app_5_0.xsd"
         version="5.0">
    <display-name>${nombre}</display-name>
    <welcome-file-list>
        <welcome-file>index.html</welcome-file>
    </welcome-file-list>
</web-app>
WEBXML
    echo "  [✔] web.xml creado en ${web_inf}"

    chown -R "tomcat:tomcat" "$web_root"
    chmod -R 755 "$web_root"
    echo "  [✔] Permisos aplicados en ${web_root}"

    # ── 6. Encabezados de seguridad vía valve en server.xml ───────
    #
    # Se agrega un HttpHeaderSecurityFilter en web.xml para
    # inyectar los headers de seguridad en todas las respuestas
    #
    if ! grep -q "HttpHeaderSecurityFilter" "${web_inf}/web.xml"; then
        sed -i "/<\/web-app>/i\\
    <filter>\\
        <filter-name>HttpHeaderSecurity<\/filter-name>\\
        <filter-class>org.apache.catalina.filters.HttpHeaderSecurityFilter<\/filter-class>\\
        <init-param><param-name>antiClickJackingOption<\/param-name><param-value>SAMEORIGIN<\/param-value><\/init-param>\\
        <init-param><param-name>xssProtectionEnabled<\/param-name><param-value>true<\/param-value><\/init-param>\\
        <init-param><param-name>blockContentTypeSniffingEnabled<\/param-name><param-value>true<\/param-value><\/init-param>\\
        <init-param><param-name>hstsEnabled<\/param-name><param-value>true<\/param-value><\/init-param>\\
        <init-param><param-name>hstsMaxAgeSeconds<\/param-name><param-value>31536000<\/param-value><\/init-param>\\
        <init-param><param-name>hstsIncludeSubDomains<\/param-name><param-value>true<\/param-value><\/init-param>\\
    <\/filter>\\
    <filter-mapping>\\
        <filter-name>HttpHeaderSecurity<\/filter-name>\\
        <url-pattern>\/*<\/url-pattern>\\
    <\/filter-mapping>" "${web_inf}/web.xml"
        echo "  [✔] Encabezados de seguridad configurados en web.xml"
    fi

    # ── 7. Ocultar información del servidor en server.xml ─────────
    #
    # server="Apache" en el Connector oculta la versión exacta de Tomcat
    #
    if ! grep -q 'server="Apache"' "$server_xml"; then
        sed -i 's/\(<Connector port="'"${puerto}"'"[^>]*\)\(\/>\)/\1 server="Apache" \2/' "$server_xml"
        echo "  [✔] Versión de Tomcat ocultada en server.xml"
    fi

    # ── 8. Reiniciar Tomcat ───────────────────────────────────────
    #
    # Tomcat requiere reinicio completo (no solo reload)
    # para aplicar cambios en server.xml y webapps
    #
    echo "────────────────────────────────────────────────────────"
    echo "Reiniciando ${tomcat_pkg}..."

    if systemctl restart "$tomcat_pkg"; then
        echo "  [✔] ${tomcat_pkg} reiniciado exitosamente"
    else
        echo "  [✘] Error al reiniciar ${tomcat_pkg}." >&2
        journalctl -xeu "$tomcat_pkg" --no-pager | tail -10 >&2
        return 1
    fi

    echo "────────────────────────────────────────────────────────"
    echo "✔ Servicio '${nombre}' configurado y activo"
    echo "  URL         : http://localhost:${puerto}/${nombre}"
    echo "  Web root    : ${web_root}"
    echo "  server.xml  : ${server_xml}"
    echo "  Logs        : ${log_dir}/"

    return 0
}

validar_puerto() {
    local puerto="$1"

    # Puertos reservados — se pueden agregar más según necesidad
    local -a puertos_reservados=(
        20   # FTP data
        21   # FTP control
        22   # SSH
        23   # Telnet
        25   # SMTP
        53   # DNS
        67   # DHCP server
        68   # DHCP client
        69   # TFTP
        110  # POP3
        111  # RPC
        119  # NNTP
        123  # NTP
        135  # RPC DCOM
        137  # NetBIOS
        138  # NetBIOS
        139  # NetBIOS
        143  # IMAP
        161  # SNMP
        162  # SNMP trap
        389  # LDAP
        443  # HTTPS
        445  # SMB
        465  # SMTPS
        514  # Syslog
        587  # SMTP submission
        636  # LDAPS
        993  # IMAPS
        995  # POP3S
        3306 # MySQL
        3389 # RDP
        5432 # PostgreSQL
        5900 # VNC
        6379 # Redis
        27017 # MongoDB
    )

    # ── 1. Verificar que sea numérico ─────────────────────────────
    if ! [[ "$puerto" =~ ^[0-9]+$ ]]; then
        echo "  [✘] '${puerto}' no es un número válido." >&2
        return 1
    fi

    # ── 2. Verificar rango 1-65535 ────────────────────────────────
    if (( puerto < 1 || puerto > 65535 )); then
        echo "  [✘] Puerto ${puerto} fuera de rango (1-65535)." >&2
        return 1
    fi

    # ── 3. Verificar que no sea un puerto reservado ───────────────
    for reservado in "${puertos_reservados[@]}"; do
        if (( puerto == reservado )); then
            # Obtener el nombre del servicio reservado del comentario
            local descripcion
            descripcion=$(grep -w "^        ${reservado}" <<< "$(declare -f validar_puerto)" \
                | awk '{$1=""; print $0}' | xargs)
            echo "  [✘] Puerto ${puerto} reservado: ${descripcion}" >&2
            return 1
        fi
    done

    # ── 4. Verificar si el puerto ya está en uso ──────────────────
    if ss -tulnp 2>/dev/null | awk '{print $5}' | grep -qw ":${puerto}$"; then
        local proceso
        proceso=$(ss -tulnp 2>/dev/null \
            | awk -v p=":${puerto}" '$5 ~ p {print $NF}' \
            | grep -oP 'users:\(\("\K[^"]+' \
            | head -1)

        echo "  [✘] Puerto ${puerto} ya está en uso${proceso:+ por '${proceso}'}." >&2
        return 1
    fi

    echo "  [✔] Puerto ${puerto} disponible y válido."
    return 0
}