function New-IISWebsite {
    param(
        [Parameter(Mandatory = $true)]
        [string]$name,

        [Parameter(Mandatory = $true)]
        [int]$port,

        [Parameter(Mandatory = $false)]
        [string]$path = "C:\WebServers\IIS"
    )

    if (-not(Test-Port -Port $port)) {
        Write-Host "Abortando instalacion..." -ForegroundColor red
        exit 1
    }

    # Importar el módulo de administración si no está cargado
    if (!(Get-Module -ListAvailable WebAdministration)) {
        Write-Error "El módulo WebAdministration no está disponible. Asegúrate de haber instalado IIS con herramientas de gestión."
        return
    }
    Import-Module WebAdministration

    # 1. Verificar si el puerto ya está siendo usado por otro sitio de IIS
    $existingSite = Get-Website | Where-Object { 
        $_.bindings.Collection.bindingInformation -like "*:${port}:*" 
    }

    if ($existingSite) {
        Write-Host "Error: El puerto $port ya está ocupado por el sitio '$($existingSite.name)'." -ForegroundColor Red
        return
    }

    # 2. Crear el directorio si no existe
    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Host "Directorio creado en: $path" -ForegroundColor Gray
    }

    # 3. Crear el sitio web
    try {
        # Creamos el sitio y su respectivo Application Pool
        New-Website -Name $name -Port $port -PhysicalPath $path -ApplicationPool $name -force

        # Crear una regla de reescritura de salida para el encabezado Server
        #Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/rewrite/outboundRules" -name "." -value @{name='RemoveServerHeader'; patternBeforeOverwriting=$true}
        #Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/rewrite/outboundRules/rule[@name='RemoveServerHeader']" -name "match" -value @{serverVariable='RESPONSE_SERVER'; pattern='.*'}
        #Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/rewrite/outboundRules/rule[@name='RemoveServerHeader']" -name "action" -value @{type='Rewrite'; value=''}
        # También es recomendable ocultar la versión de ASP.NET si la usas
        #Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/httpProtocol/customHeaders" -name "." -value @{name='X-Powered-By';value=''}

        #$verbos = @("TRACE", "TRACK", "DELETE")

        Set-IISSecurity -SiteName $name -SecurityHeaders -HideServerInfo 
        Remove-IISServerHeader -SiteName $name -Method "URLRewrite"

        #foreach ($v in $verbos) {
            # Verificamos si ya existe el bloqueo para ese verbo
        #     $check = (Get-WebConfigurationProperty -Filter "system.webServer/security/requestFiltering/verbs" -PSPath "IIS:\" -Name ".").Collection | Select-Object verb, allowed
            
        #     if (!$check) {
        #         Add-WebConfigurationProperty -Filter "system.webServer/security/requestFiltering/verbs" -Name "." -Value @{verb=$v; allowed=$false} -PSPath "IIS:\"
        #         Write-Host "Bloqueado: $v" -ForegroundColor Green
        #     } else {
        #         Write-Host "El verbo $v ya estaba bloqueado." -ForegroundColor Yellow
        #     }
        # }

        $aux = Get-ChildItem IIS:\AppPools |  findstr "ServicioWebIIS"

        if ($aux -eq $null) {
            New-WebAppPool -Name "ServicioWebIIS" -force
        }

        Set-ItemProperty "IIS:\Sites\ServicioWebIIS" -Name applicationPool -Value "ServicioWebIIS"
        Start-WebAppPool -Name "ServicioWebIIS"
        Start-Website -Name "ServicioWebIIS"
        #$defaultFile = "index.html" # Cambia esto por el nombre de tu archivo
        #Add-WebConfigurationProperty -Filter /system.webServer/defaultDocument/files -Name "." -Value @{value=$defaultFile} -PSPath "IIS:\Sites\$name"

        $resul = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp\").VersionString
        $resul = $resul -split " " 

        $plantilla = Formar-Plantilla -nombre "IIS" -version $($resul[1]) -puerto $port

        $plantilla | Out-File -FilePath "$path\index.html" -Encoding utf8

        if (Get-NetFirewallRule -DisplayName "ServicioWebIIS" -ErrorAction SilentlyContinue) {
            Remove-NetFirewallRule -DisplayName "ServicioWebIIS"
        }

        New-NetFirewallRule -displayname "ServicioWebIIS" -Protocol TCP -LocalPort $port -Action Allow -Direction Inbound -LocalAddress Any

        Write-Host "¡Sitio '$name' creado exitosamente en el puerto $port!" -ForegroundColor Green
        Write-Host "Ruta física: $path" -ForegroundColor White
    } catch {
        Write-Error "No se pudo crear el sitio web: $_"
    }
}

function Install-IISServer {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$install,

        [Parameter(Mandatory = $false)]
        [switch]$silent
    )

    if ($install) {
        Write-Host "Comprobando estado de IIS y herramientas de gestión..." -ForegroundColor Cyan
        
        # Verificamos tanto el servidor como las herramientas de administración
        $iisFeature = Get-WindowsFeature | Where-Object { $_.Name -eq "Web-Server" -or $_.Name -eq "Web-Mgmt-Tools" }
        $allInstalled = ($iisFeature | Where-Object { $_.Installed }).Count -eq $iisFeature.Count

        if ($allInstalled) {
            Write-Host "IIS y el Módulo de Administración ya están instalados." -ForegroundColor Yellow
            return
        }

        Write-Host "Instalando IIS con RSAT-Web-Server (Administración PowerShell)..." -ForegroundColor White
        
        try {
            # El parámetro -IncludeManagementTools es CLAVE aquí
            if ($silent) {
                Install-WindowsFeature -Name Web-Server -IncludeManagementTools *>$null
            }
            else {
                Install-WindowsFeature -Name Web-Server -IncludeManagementTools
            }
            
            # Forzamos la importación del módulo recién instalado para la sesión actual
            Import-Module WebAdministration -ErrorAction SilentlyContinue
            
            Write-Host "¡Instalación completada con éxito!" -ForegroundColor Green
        }
        catch {
            Write-Error "Error durante la instalación: $_"
        }
    } 
    else {
        Write-Host "Use '-install' para proceder." -ForegroundColor Magenta
    }
}

function Configure-ApacheService {    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ApachePath,
        
        [Parameter(Mandatory = $false)]
        [string]$ServiceName = "Apache",
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 65535)]
        [int]$Port = 80,
        
        [Parameter(Mandatory = $false)]
        [string]$DocumentRoot,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Automatic", "Manual", "Disabled")]
        [string]$StartupType = "Automatic",
        
        [Parameter(Mandatory = $false)]
        [switch]$CreateFirewallRule,
    
        [Parameter(Mandatory = $false)]
        [switch]$SkipInstall  
    )
    
    try {

        if (-not(Test-Port -Port $Port)) {
            Write-Host "Abortando instalacion..." -ForegroundColor red
            exit 1
        }

        # Verificar privilegios de administrador
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            Write-Error "Se requieren privilegios de administrador. Ejecuta PowerShell como Administrador."
            return $false
        }
        
        Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║        INSTALACIÓN DE SERVICIO APACHE                    ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
        
        # Verificar si Chocolatey está instalado
        $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
        if (-not $chocoCmd) {
            Write-Error "Chocolatey no está instalado. Instálalo desde https://chocolatey.org o usa -SkipInstall"
            return $false
        }
        
        # Auto-detectar o instalar Apache
        if (-not $ApachePath) {
            Write-Host "Buscando instalación de Apache..." -ForegroundColor Cyan
            
            # Rutas posibles donde Chocolatey puede instalar Apache
            $possiblePaths = @(
                "$env:USERPROFILE\AppData\Roaming\Apache24",  # Windows Server Core
                "C:\Users\Administrator\AppData\Roaming\Apache24",  # Windows Server Core (Admin)
                "C:\Apache24",
                "C:\Apache",
                "C:\Program Files\Apache Software Foundation\Apache2.4",
                "$env:ProgramFiles\Apache Software Foundation\Apache2.4",
                "C:\xampp\apache",
                "$env:LOCALAPPDATA\Apache24",
                "$env:APPDATA\Apache24"
            )
            
            # Intentar obtener ruta desde Chocolatey
            $chocoInfo = choco list apache-httpd --local-only --exact 2>$null
            
            if ($chocoInfo) {
                Write-Verbose "Apache instalado vía Chocolatey"
            }
            
            foreach ($path in $possiblePaths) {
                if (Test-Path "$path\bin\httpd.exe") {
                    $ApachePath = $path
                    Write-Host "✓ Apache encontrado en: $ApachePath" -ForegroundColor Green
                    break
                }
            }
            
            # Si no se encontró, buscar en AppData recursivamente
            if (-not $ApachePath) {
                Write-Verbose "Buscando Apache en AppData..."
                $appDataSearch = Get-ChildItem -Path "$env:USERPROFILE\AppData" -Recurse -Filter "httpd.exe" -ErrorAction SilentlyContinue | 
                Where-Object { $_.DirectoryName -like "*\bin" } | 
                Select-Object -First 1
                
                if ($appDataSearch) {
                    $ApachePath = Split-Path (Split-Path $appDataSearch.FullName -Parent) -Parent
                    Write-Host "✓ Apache encontrado en: $ApachePath" -ForegroundColor Green
                }
            }
            
            # Si no se encontró Apache lo saca
            if (-not $ApachePath) {
                Write-Error "No se encontró Apache. Regrese al menu para instalarlo."
                return $false
            }
        }
        
        # Verificar que existe httpd.exe
        $httpdPath = Join-Path $ApachePath "bin\httpd.exe"
        if (-not (Test-Path $httpdPath)) {
            Write-Error "No se encontró httpd.exe en $ApachePath\bin"
            return $false
        }
        
        # Configurar DocumentRoot si no se especificó
        if (-not $DocumentRoot) {
            $DocumentRoot = "C:\WebServers\Apache"
        }
        
        # Crear directorio htdocs si no existe
        if (-not (Test-Path $DocumentRoot)) {
            New-Item -Path $DocumentRoot -ItemType Directory -Force | Out-Null
            Write-Host "✓ Directorio creado: $DocumentRoot" -ForegroundColor Green
        }

        $version = choco list apache-httpd | findstr "apache-httpd"
        $version = $version -split " "

        $plantilla = Formar-Plantilla -nombre $ServiceName -version $version[1] -puerto $Port

        Set-Content -Value $plantilla -Path "C:\WebServers\Apache\index.html"
        
        
        # Mostrar configuración
        Write-Host "Configuración:" -ForegroundColor White
        Write-Host "  Apache Path:    $ApachePath" -ForegroundColor Gray
        Write-Host "  httpd.exe:      $httpdPath" -ForegroundColor Gray
        Write-Host "  Servicio:       $ServiceName" -ForegroundColor Gray
        Write-Host "  Puerto:         $Port" -ForegroundColor Gray
        Write-Host "  DocumentRoot:   $DocumentRoot" -ForegroundColor Gray
        Write-Host "  Inicio:         $StartupType`n" -ForegroundColor Gray
        
        # Configurar httpd.conf
        Write-Host "Configurando httpd.conf..." -ForegroundColor Cyan
        $configPath = Join-Path $ApachePath "conf\httpd.conf"
        
        if (Test-Path $configPath) {
            # Hacer backup
            $backupPath = "$configPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item $configPath $backupPath
            Write-Host "✓ Backup creado: $backupPath" -ForegroundColor Green
            
            # Leer configuración
            $config = Get-Content $configPath -Raw
            
            # Actualizar puerto
            $config = $config -replace 'Listen\s+\d+', "Listen $Port"
            
            # Actualizar ServerRoot (normalizar ruta para Apache)
            $serverRoot = $ApachePath -replace '\\', '/'
            $config = $config -replace 'Define SRVROOT ".*?"', "Define SRVROOT `"$serverRoot`""
            $config = $config -replace 'ServerRoot ".*?"', "ServerRoot `"$serverRoot`""
            
            # Actualizar DocumentRoot (normalizar ruta)
            $docRoot = $DocumentRoot -replace '\\', '/'
            $config = $config -replace 'DocumentRoot ".*?"', "DocumentRoot `"$docRoot`""
            $config = $config -replace '<Directory ".*?/htdocs">', "<Directory `"$docRoot`">"
            
            # Guardar configuración
            Set-Content -Path $configPath -Value $config -Encoding UTF8
            Write-Host "✓ httpd.conf actualizado" -ForegroundColor Green
        } else {
            Write-Warning "No se encontró httpd.conf en $configPath"
        }
        
        # Configurar tipo de inicio
        Write-Host "Configurando tipo de inicio..." -ForegroundColor Cyan
        Set-Service -Name $ServiceName -StartupType $StartupType
        Write-Host "✓ Tipo de inicio configurado: $StartupType" -ForegroundColor Green
        
        # Crear regla de firewall si se solicitó
        if ($CreateFirewallRule) {
            Write-Host "`nCreando regla de firewall..." -ForegroundColor Cyan
            
            # Verificar si existe la función New-FirewallRule
            if (Get-Command New-FirewallRule -ErrorAction SilentlyContinue) {
                $firewallResult = New-FirewallRule -DisplayName "Apache HTTP Server" `
                    -Port $Port `
                    -Protocol TCP
                if ($firewallResult) {
                    Write-Host "✓ Regla de firewall creada" -ForegroundColor Green
                }
            } else {
                Write-Warning "Función New-FirewallRule no encontrada. Crea la regla manualmente."
            }
        }
        
        # Mostrar resumen
        Write-Host "`n" + ("=" * 60) -ForegroundColor Green
        Write-Host "✓ CONFIGURACION COMPLETADA" -ForegroundColor Green
        Write-Host ("=" * 60) -ForegroundColor Green
        Write-Host "`nPróximos pasos:" -ForegroundColor Cyan
        Write-Host "  1. Iniciar servicio:" -ForegroundColor White
        Write-Host "     Start-ApacheService" -ForegroundColor Yellow
        Write-Host "  2. Verificar estado:" -ForegroundColor White
        Write-Host "     Get-ApacheStatus" -ForegroundColor Yellow
        Write-Host "  3. Acceder a Apache:" -ForegroundColor White
        Write-Host "     http://localhost:$Port" -ForegroundColor Yellow
        Write-Host "`nArchivos importantes:" -ForegroundColor Cyan
        Write-Host "  Configuración: $configPath" -ForegroundColor Gray
        Write-Host "  DocumentRoot:  $DocumentRoot" -ForegroundColor Gray
        Write-Host "  Logs:          $ApachePath\logs" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "Reiniciando servicio..." -ForegroundColor Cyan
        Restart-Service Apache
        
        Set-ApacheSecurity -SecurityHeaders -HideServerInfo -RestartService -DisableDirectoryListing

        
    } catch {
        Write-Error "Error durante la instalación: $_"
        return $false
    }
}

function Formar-Plantilla {
    param(
        [string]$nombre,
        [string]$version,
        [int]$puerto
    )


    $plantilla = "<!DOCTYPE html>
<html>
  <head>
    <title>Estatus Servicio</title>
  </head>
  <body>
    <div class='info'>
      <p>Nombre del servicio: $nombre</p>
      <p>Version: $version</p>
      <p>Puerto: $puerto</p>
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
      display:inline-block;
      background: rgb(240,230,220);
      margin-top: 48px;
      border-radius: 8px;
      border: 2px solid black;
      padding: 8px;
    }

  </style>
</html>"

    return $plantilla
}

function Set-ApacheSecurity {
    <#
    .SYNOPSIS
        Configura opciones de seguridad en Apache HTTP Server.
    
    .DESCRIPTION
        Aplica configuraciones de seguridad recomendadas en Apache incluyendo:
        - Deshabilitar métodos HTTP peligrosos (TRACE, TRACK, DELETE, PUT)
        - Configurar encabezados de seguridad
        - Deshabilitar información de versión
        - Configurar límites de peticiones
        - Y más opciones de hardening
    
    .PARAMETER ApachePath
        Ruta de instalación de Apache (intenta auto-detectar si no se especifica).
    
    .PARAMETER DisabledMethods
        Métodos HTTP a deshabilitar. Por defecto: TRACE, TRACK, DELETE, PUT, OPTIONS
    
    .PARAMETER SecurityHeaders
        Si se especifica, agrega encabezados de seguridad (X-Frame-Options, CSP, etc.).
    
    .PARAMETER HideServerInfo
        Si se especifica, oculta información de versión de Apache.
    
    .PARAMETER DisableDirectoryListing
        Si se especifica, deshabilita el listado de directorios.
    
    .PARAMETER CreateBackup
        Si se especifica, crea backup de la configuración antes de modificarla.
    
    .PARAMETER RestartService
        Si se especifica, reinicia Apache después de aplicar cambios.
    
    .EXAMPLE
        Set-ApacheSecurity
        Aplica configuración de seguridad básica.
    
    .EXAMPLE
        Set-ApacheSecurity -SecurityHeaders -HideServerInfo -RestartService
        Aplica todas las configuraciones de seguridad y reinicia Apache.
    
    .EXAMPLE
        Set-ApacheSecurity -DisabledMethods @("TRACE", "TRACK") -SecurityHeaders
        Deshabilita solo TRACE y TRACK, y agrega encabezados de seguridad.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ApachePath,
        
        [Parameter(Mandatory = $false)]
        [string[]]$DisabledMethods = @("TRACE", "TRACK", "DELETE", "PUT", "OPTIONS"),
        
        [Parameter(Mandatory = $false)]
        [switch]$SecurityHeaders,
        
        [Parameter(Mandatory = $false)]
        [switch]$HideServerInfo,
        
        [Parameter(Mandatory = $false)]
        [switch]$DisableDirectoryListing,
        
        [Parameter(Mandatory = $false)]
        [switch]$CreateBackup = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$RestartService
    )
    
    try {
        Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║        CONFIGURACIÓN DE SEGURIDAD APACHE                 ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
        
        # Buscar Apache si no se especificó
        if (-not $ApachePath) {
            Write-Host "Buscando instalación de Apache..." -ForegroundColor Cyan
            
            $possiblePaths = @(
                "$env:USERPROFILE\AppData\Roaming\Apache24",
                "C:\Users\Administrator\AppData\Roaming\Apache24",
                "C:\Apache24",
                "C:\Apache",
                "$env:ProgramFiles\Apache Software Foundation\Apache2.4",
                "C:\xampp\apache"
            )
            
            foreach ($path in $possiblePaths) {
                if (Test-Path "$path\bin\httpd.exe") {
                    $ApachePath = $path
                    Write-Host "✓ Apache encontrado en: $ApachePath" -ForegroundColor Green
                    break
                }
            }
            
            if (-not $ApachePath) {
                # Búsqueda recursiva
                $found = Get-ChildItem -Path "$env:USERPROFILE\AppData" -Recurse -Filter "httpd.exe" -ErrorAction SilentlyContinue | 
                         Where-Object { $_.DirectoryName -like "*\bin" } | 
                         Select-Object -First 1
                
                if ($found) {
                    $ApachePath = Split-Path (Split-Path $found.FullName -Parent) -Parent
                    Write-Host "✓ Apache encontrado en: $ApachePath" -ForegroundColor Green
                }
            }
            
            if (-not $ApachePath) {
                Write-Error "No se encontró Apache. Especifica la ruta con -ApachePath"
                return $false
            }
        }
        
        # Verificar que existe httpd.conf
        $httpdConfPath = Join-Path $ApachePath "conf\httpd.conf"
        if (-not (Test-Path $httpdConfPath)) {
            Write-Error "No se encontró httpd.conf en $httpdConfPath"
            return $false
        }

        #$config = Get-Content $httpdConfPath -Raw
            
        #$config = $config -replace '#LoadModule headers_module modules/mod_headers.so', 'LoadModule headers_module modules/mod_headers.so'
            
            # Guardar configuración
        #Set-Content -Path $httpdConfPath -Value $config -Encoding UTF8
        
        # Crear directorio conf/extra si no existe
        $extraConfDir = Join-Path $ApachePath "conf\extra"
        if (-not (Test-Path $extraConfDir)) {
            New-Item -Path $extraConfDir -ItemType Directory -Force | Out-Null
        }
        
        # Crear backup
        if ($CreateBackup) {
            $backupPath = "$httpdConfPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item $httpdConfPath $backupPath
            Write-Host "✓ Backup creado: $backupPath" -ForegroundColor Green
        }
        
        # Ruta del archivo de seguridad
        $securityConfPath = Join-Path $ApachePath "conf\extra\httpd-security.conf"
        
        Write-Host "`nAplicando configuraciones de seguridad..." -ForegroundColor Cyan
        
        # ============================================
        # Crear archivo de configuración de seguridad
        # ============================================
        
        $securityConfig = @"
# ============================================
# Configuración de Seguridad de Apache
# Generado automáticamente por Set-ApacheSecurity
# Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# ============================================

"@
        
        # Deshabilitar métodos HTTP peligrosos
        if ($DisabledMethods.Count -gt 0) {
            $methodsList = $DisabledMethods -join " "
            $securityConfig += @"

# ============================================
# Deshabilitar métodos HTTP peligrosos
# ============================================

# Bloquear específicamente TRACE y otros métodos
TraceEnable off

<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{REQUEST_METHOD} ^(TRACE|TRACK|DELETE|PUT|OPTIONS)$ [NC]
    RewriteRule .* - [F,L]
</IfModule>

"@
            Write-Host "  ✓ Métodos HTTP deshabilitados: $methodsList" -ForegroundColor Green
        }
        
        # Configurar encabezados de seguridad
        if ($SecurityHeaders) {
            $securityConfig += @"

# ============================================
# Encabezados de Seguridad
# ============================================
<IfModule mod_headers.c>
    # Prevenir clickjacking
    Header always set X-Frame-Options "SAMEORIGIN"
    
    # Prevenir MIME-sniffing
    Header always set X-Content-Type-Options "nosniff"
    
    # Activar protección XSS del navegador
    Header always set X-XSS-Protection "1; mode=block"
    
    # Content Security Policy (ajusta según tus necesidades)
    Header always set Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';"
    
    # Referrer Policy
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    
    # Permissions Policy (antes Feature-Policy)
    Header always set Permissions-Policy "geolocation=(), microphone=(), camera=()"
    
    # HSTS - Forzar HTTPS (descomenta si usas SSL)
    # Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    
    # Remover encabezados que revelan información
    Header unset X-Powered-By
    Header unset Server
</IfModule>

"@
            Write-Host "  ✓ Encabezados de seguridad configurados" -ForegroundColor Green
        }
        
        # Ocultar información del servidor
        if ($HideServerInfo) {
            $securityConfig += @"

# ============================================
# Ocultar información del servidor
# ============================================
ServerTokens Prod
ServerSignature Off

"@
            Write-Host "  ✓ Información del servidor ocultada" -ForegroundColor Green
        }
        
        # Deshabilitar listado de directorios
        if ($DisableDirectoryListing) {
            $securityConfig += @"

# ============================================
# Deshabilitar listado de directorios
# ============================================
<Directory />
    Options -Indexes
    AllowOverride None
    Require all denied
</Directory>

"@
            Write-Host "  ✓ Listado de directorios deshabilitado" -ForegroundColor Green
        }
        
        # Configuraciones adicionales de seguridad
        $securityConfig += @"

# ============================================
# Configuraciones adicionales de seguridad
# ============================================

# Límites de peticiones para prevenir DoS
<IfModule mod_reqtimeout.c>
    RequestReadTimeout header=20-40,MinRate=500 body=20,MinRate=500
</IfModule>

# Timeout para conexiones
Timeout 60

# Limitar tamaño de peticiones
LimitRequestBody 10485760

# Limitar campos en el header
LimitRequestFields 100
LimitRequestFieldSize 8190
LimitRequestLine 8190

# Deshabilitar .htaccess en producción (mejora rendimiento)
# <Directory />
#     AllowOverride None
# </Directory>

# Proteger archivos sensibles
<FilesMatch "^\.ht">
    Require all denied
</FilesMatch>

<FilesMatch "\.(conf|ini|log|md|yml|yaml)$">
    Require all denied
</FilesMatch>

# Prevenir acceso a archivos de respaldo
<FilesMatch "~$">
    Require all denied
</FilesMatch>

# ============================================
# Fin de configuración de seguridad
# ============================================

"@
        
        # Guardar archivo de seguridad
        Set-Content -Path $securityConfPath -Value $securityConfig -Encoding UTF8
        Write-Host "`n✓ Archivo de seguridad creado: $securityConfPath" -ForegroundColor Green
        
        # ============================================
        # Modificar httpd.conf para incluir el archivo de seguridad
        # ============================================
        
        $httpdConfig = Get-Content $httpdConfPath -Raw
        
        # Verificar si ya está incluido
        if ($httpdConfig -notmatch "Include.*httpd-security\.conf") {
            # Agregar al final del archivo
            $includeStatement = "`n`n# Configuración de seguridad`nInclude conf/extra/httpd-security.conf`n"
            Add-Content -Path $httpdConfPath -Value $includeStatement -Encoding UTF8
            Write-Host "✓ httpd.conf actualizado para incluir configuración de seguridad" -ForegroundColor Green
        } else {
            Write-Host "✓ httpd.conf ya incluye la configuración de seguridad" -ForegroundColor Yellow
        }
        
        # Verificar que mod_headers y mod_rewrite están habilitados
        Write-Host "`nVerificando módulos necesarios..." -ForegroundColor Cyan
        
        $modulesToEnable = @("headers_module", "rewrite_module", "reqtimeout_module")
        $configUpdated = $false
        
        foreach ($module in $modulesToEnable) {
            $modulePattern = "LoadModule\s+$module"
            $commentedPattern = "#\s*LoadModule\s+$module"
            
            if ($httpdConfig -match $commentedPattern) {
                # Descomentar el módulo
                $httpdConfig = $httpdConfig -replace "#(\s*LoadModule\s+$module)", '$1'
                $configUpdated = $true
                Write-Host "  ✓ $module habilitado" -ForegroundColor Green
            }
            elseif ($httpdConfig -match $modulePattern) {
                Write-Host "  ✓ $module ya está habilitado" -ForegroundColor Gray
            }
            else {
                Write-Warning "  ⚠ $module no encontrado en la configuración"
            }
        }
        
        if ($configUpdated) {
            Set-Content -Path $httpdConfPath -Value $httpdConfig -Encoding UTF8
            Write-Host "`n✓ Módulos habilitados en httpd.conf" -ForegroundColor Green
        }
        
        # Verificar sintaxis de configuración
        Write-Host "`nVerificando configuración de Apache..." -ForegroundColor Cyan
        $httpdExe = Join-Path $ApachePath "bin\httpd.exe"
        
        if (Test-Path $httpdExe) {
            $syntaxCheck = & $httpdExe -t 2>&1
            $syntaxCheckStr = $syntaxCheck | Out-String
            
            if ($syntaxCheckStr -match "Syntax OK") {
                Write-Host "✓ Configuración válida (Syntax OK)" -ForegroundColor Green
            } else {
                Write-Warning "Advertencia al validar configuración:"
                Write-Host $syntaxCheckStr -ForegroundColor Yellow
            }
        }
        
        # Mostrar resumen
        Write-Host "`n" + ("=" * 60) -ForegroundColor Green
        Write-Host "✓ CONFIGURACIÓN DE SEGURIDAD COMPLETADA" -ForegroundColor Green
        Write-Host ("=" * 60) -ForegroundColor Green
        
        Write-Host "`nConfiguraciones aplicadas:" -ForegroundColor Cyan
        if ($DisabledMethods.Count -gt 0) {
            Write-Host "  • Métodos HTTP deshabilitados: $($DisabledMethods -join ', ')" -ForegroundColor White
        }
        if ($SecurityHeaders) {
            Write-Host "  • Encabezados de seguridad configurados" -ForegroundColor White
        }
        if ($HideServerInfo) {
            Write-Host "  • Información del servidor ocultada" -ForegroundColor White
        }
        if ($DisableDirectoryListing) {
            Write-Host "  • Listado de directorios deshabilitado" -ForegroundColor White
        }
        
        Write-Host "`nArchivos modificados:" -ForegroundColor Cyan
        Write-Host "  • $securityConfPath" -ForegroundColor Gray
        Write-Host "  • $httpdConfPath" -ForegroundColor Gray
        if ($CreateBackup) {
            Write-Host "  • Backup: $backupPath" -ForegroundColor Gray
        }
        
        # Reiniciar servicio si se solicitó
        if ($RestartService) {
            Write-Host "`nReiniciando Apache..." -ForegroundColor Cyan
            
            # Verificar si existe la función Restart-ApacheService
            if (Get-Command Restart-ApacheService -ErrorAction SilentlyContinue) {
                Restart-ApacheService
            } else {
                # Intentar reiniciar directamente
                $service = Get-Service -Name "Apache" -ErrorAction SilentlyContinue
                if ($service) {
                    Restart-Service -Name "Apache" -Force
                    Write-Host "✓ Apache reiniciado" -ForegroundColor Green
                } else {
                    Write-Warning "No se pudo reiniciar Apache automáticamente. Reinícialo manualmente."
                }
            }
        } else {
            Write-Host "`n⚠ Para aplicar los cambios, reinicia Apache:" -ForegroundColor Yellow
            Write-Host "  Restart-ApacheService" -ForegroundColor White
            Write-Host "  o" -ForegroundColor Gray
            Write-Host "  Restart-Service Apache2.4" -ForegroundColor White
        }
        
        Write-Host ""
        return $true
        
    } catch {
        Write-Error "Error al configurar seguridad: $_"
        return $false
    }
}

function Set-NginxSecurity {
    <#
    .SYNOPSIS
        Configura opciones de seguridad en Nginx.
    
    .DESCRIPTION
        Aplica configuraciones de seguridad recomendadas en Nginx incluyendo:
        - Deshabilitar métodos HTTP peligrosos (TRACE, DELETE, PUT, etc.)
        - Configurar encabezados de seguridad
        - Ocultar información de versión del servidor
        - Configurar límites de peticiones
    
    .PARAMETER NginxPath
        Ruta de instalación de Nginx (intenta auto-detectar si no se especifica).
    
    .PARAMETER DisabledMethods
        Métodos HTTP a deshabilitar. Por defecto: TRACE, DELETE, PUT, OPTIONS, CONNECT
    
    .PARAMETER SecurityHeaders
        Si se especifica, agrega encabezados de seguridad.
    
    .PARAMETER HideServerInfo
        Si se especifica, oculta información de versión de Nginx.
    
    .PARAMETER CreateBackup
        Si se especifica, crea backup de la configuración antes de modificarla.
    
    .PARAMETER RestartService
        Si se especifica, reinicia Nginx después de aplicar cambios.
    
    .EXAMPLE
        Set-NginxSecurity
        Aplica configuración de seguridad básica.
    
    .EXAMPLE
        Set-NginxSecurity -SecurityHeaders -HideServerInfo -RestartService
        Aplica todas las configuraciones de seguridad y reinicia Nginx.
    
    .EXAMPLE
        Set-NginxSecurity -DisabledMethods @("TRACE", "DELETE") -SecurityHeaders
        Deshabilita solo TRACE y DELETE, y agrega encabezados de seguridad.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$NginxPath,
        
        [Parameter(Mandatory = $false)]
        [string[]]$DisabledMethods = @("TRACE", "DELETE", "PUT", "OPTIONS", "CONNECT"),
        
        [Parameter(Mandatory = $false)]
        [switch]$SecurityHeaders,
        
        [Parameter(Mandatory = $false)]
        [switch]$HideServerInfo,
        
        [Parameter(Mandatory = $false)]
        [switch]$CreateBackup = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$RestartService
    )
    
    try {
        Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║        CONFIGURACIÓN DE SEGURIDAD NGINX                  ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
        
        # Buscar Nginx si no se especificó
        if (-not $NginxPath) {
            Write-Host "Buscando instalación de Nginx..." -ForegroundColor Cyan
            
            $possiblePaths = @(
                "$env:USERPROFILE\AppData\Roaming\nginx",
                "C:\Users\Administrator\AppData\Roaming\nginx",
                "C:\nginx",
                "C:\nginx-*",
                "$env:ProgramFiles\nginx",
                "C:\tools\nginx"
            )
            
            foreach ($path in $possiblePaths) {
                # Manejar wildcards
                if ($path -like "*`**") {
                    $resolved = Get-Item $path -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($resolved -and (Test-Path "$($resolved.FullName)\nginx.exe")) {
                        $NginxPath = $resolved.FullName
                        Write-Host "✓ Nginx encontrado en: $NginxPath" -ForegroundColor Green
                        break
                    }
                } elseif (Test-Path "$path\nginx.exe") {
                    $NginxPath = $path
                    Write-Host "✓ Nginx encontrado en: $NginxPath" -ForegroundColor Green
                    break
                }
            }
            
            if (-not $NginxPath) {
                # Búsqueda recursiva
                $found = Get-ChildItem -Path "$env:USERPROFILE\AppData" -Recurse -Filter "nginx.exe" -ErrorAction SilentlyContinue | 
                         Select-Object -First 1
                
                if ($found) {
                    $NginxPath = Split-Path $found.FullName -Parent
                    Write-Host "✓ Nginx encontrado en: $NginxPath" -ForegroundColor Green
                }
            }
            
            if (-not $NginxPath) {
                Write-Error "No se encontró Nginx. Especifica la ruta con -NginxPath"
                Write-Host "`nPuedes instalar Nginx con:" -ForegroundColor Yellow
                Write-Host "  choco install nginx -y" -ForegroundColor White
                return $false
            }
        }
        
        # Verificar que existe nginx.conf
        $nginxConfPath = Join-Path $NginxPath "\conf\nginx.conf"
        if (-not (Test-Path $nginxConfPath)) {
            Write-Error "No se encontró nginx.conf en $nginxConfPath"
            return $false
        }
        
        # Crear backup
        if ($CreateBackup) {
            $backupPath = "$nginxConfPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item $nginxConfPath $backupPath
            Write-Host "✓ Backup creado: $backupPath" -ForegroundColor Green
        }
        
        Write-Host "`nAplicando configuraciones de seguridad..." -ForegroundColor Cyan
        
        # Leer configuración actual
        $config = Get-Content $nginxConfPath -Raw
        
        # ============================================
        # Ocultar información del servidor
        # ============================================
        if ($HideServerInfo) {
            # Buscar el bloque http
            if ($config -match "http\s*\{") {
                # Verificar si server_tokens ya existe
                if ($config -notmatch "server_tokens\s+off") {
                    # Agregar server_tokens off dentro del bloque http
                    $config = $config -replace "(http\s*\{)", "`$1`n    # Ocultar versión de Nginx`n    server_tokens off;`n"
                    Write-Host "  ✓ server_tokens off configurado" -ForegroundColor Green
                } else {
                    Write-Host "  ✓ server_tokens ya está configurado" -ForegroundColor Gray
                }
            }
        }
        
        # ============================================
        # Configurar encabezados de seguridad y métodos HTTP
        # ============================================
        
        # Crear configuración de seguridad para agregar dentro de server o location
        $securityBlock = ""
        
        if ($SecurityHeaders -or $DisabledMethods.Count -gt 0) {
            $securityBlock = "`n    # ============================================`n"
            $securityBlock += "    # Configuracion de Seguridad`n"
            $securityBlock += "    # ============================================`n"
            
            # Encabezados de seguridad
            if ($SecurityHeaders) {
                $securityBlock += @"
    
    # Encabezados de Seguridad
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
    
"@
                Write-Host "  ✓ Encabezados de seguridad configurados" -ForegroundColor Green
            }
            
            # Deshabilitar métodos HTTP peligrosos
            if ($DisabledMethods.Count -gt 0) {
                $methodsList = $DisabledMethods -join "|"
                $securityBlock += @"
    
    # Bloquear metodos HTTP peligrosos
    if (`$request_method !~ ^(GET|HEAD|POST)$) {
        return 405;
    }
    
"@
                Write-Host "  ✓ Métodos HTTP deshabilitados: $($DisabledMethods -join ', ')" -ForegroundColor Green
            }
        }

# Agregar configuración de seguridad al bloque server principal
        if ($securityBlock) {
            # Verificar si ya existe configuración de seguridad en el bloque server
            if ($config -match "# Configuracion de Seguridad") {
                Write-Host "  • Configuración de seguridad ya existe en bloque server (omitiendo)" -ForegroundColor Gray
            } else {
                # Buscar el primer bloque server y agregar la configuración después de server_name
                if ($config -match "(?m)^[^#]*server\s*\{[^}]*server_name")  {
                    $config = $config -replace "(?m)^(\s*server_name\s+[^;]+;)", "`$1$securityBlock"
                    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                    [System.IO.File]::WriteAllText($nginxConfPath, $config, $utf8NoBom)
                    Write-Host "  ✓ Configuración agregada después de server_name" -ForegroundColor Green
                } 
                # Si no encuentra server_name, agregar después de la apertura del bloque server
                elseif ($config -match "(?m)^[^#]*server\s*\{") {
                    $config = $config -replace "(?m)^[^#]*server\s*\{", "`$1$securityBlock"
                    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                    [System.IO.File]::WriteAllText($nginxConfPath, $config, $utf8NoBom)
                    Write-Host "  ✓ Configuración agregada al inicio del bloque server" -ForegroundColor Green
                }
                else {
                    Write-Warning "No se encontró bloque 'server' en nginx.conf"
                }
            }
        }
        
        # ============================================
        # Configuraciones adicionales de seguridad
        # ============================================
        
        # Agregar límites de peticiones si no existen
        if ($config -notmatch "client_body_timeout") {
            $limitsConfig = @"
    
    # Limites de peticiones para prevenir DoS
    client_body_timeout 12;
    client_header_timeout 12;
    send_timeout 10;
    client_max_body_size 10m;
    
"@
            # Agregar dentro del bloque http
            if ($config -match "http\s*\{") {
                $config = $config -replace "(http\s*\{)", "`$1$limitsConfig"
                $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText($nginxConfPath, $config, $utf8NoBom)
            }
        }
                
        # Guardar configuración
        #Set-Content -Path $nginxConfPath -Value $config -Encoding UTF8
        Write-Host "`n✓ nginx.conf actualizado" -ForegroundColor Green
        
        # Verificar sintaxis de configuración
        Write-Host "`nVerificando configuración de Nginx..." -ForegroundColor Cyan
        $nginxExe = Join-Path $NginxPath "nginx.exe"
        
        if (Test-Path $nginxExe) {
            Push-Location $NginxPath
            $syntaxCheck = & .\nginx.exe -t 2>&1
            Pop-Location
            
            $syntaxCheckStr = $syntaxCheck | Out-String
            
            if ($syntaxCheckStr -match "test is successful" -or $syntaxCheckStr -match "syntax is ok") {
                Write-Host "✓ Configuración válida" -ForegroundColor Green
            } else {
                Write-Host "✗ ERROR: Configuración inválida" -ForegroundColor Red
                Write-Host $syntaxCheckStr -ForegroundColor Yellow
                
                Write-Host "`n⚠ La configuración tiene errores. ¿Deseas restaurar el backup? (S/N): " -NoNewline -ForegroundColor Yellow
                $restoreResponse = Read-Host
                
                if ($restoreResponse -match '^[sS]$') {
                    Copy-Item $backupPath $nginxConfPath -Force
                    Write-Host "✓ Configuración restaurada desde backup" -ForegroundColor Green
                    return $false
                } else {
                    Write-Host "`nRevisa la configuración manualmente: $nginxConfPath" -ForegroundColor Yellow
                    return $false
                }
            }
        }
        
        # Mostrar resumen
        Write-Host "`n" + ("=" * 60) -ForegroundColor Green
        Write-Host "✓ CONFIGURACIÓN DE SEGURIDAD COMPLETADA" -ForegroundColor Green
        Write-Host ("=" * 60) -ForegroundColor Green
        
        Write-Host "`nConfiguraciones aplicadas:" -ForegroundColor Cyan
        if ($DisabledMethods.Count -gt 0) {
            Write-Host "  • Métodos HTTP bloqueados: $($DisabledMethods -join ', ')" -ForegroundColor White
        }
        if ($SecurityHeaders) {
            Write-Host "  • Encabezados de seguridad configurados" -ForegroundColor White
        }
        if ($HideServerInfo) {
            Write-Host "  • Información del servidor ocultada (server_tokens off)" -ForegroundColor White
        }
        
        Write-Host "`nArchivos modificados:" -ForegroundColor Cyan
        Write-Host "  • $nginxConfPath" -ForegroundColor Gray
        if ($CreateBackup) {
            Write-Host "  • Backup: $backupPath" -ForegroundColor Gray
        }
        
        # Reiniciar servicio si se solicitó
        if ($RestartService) {
            Write-Host "`nReiniciando Nginx..." -ForegroundColor Cyan
            
            # Intentar con servicio de Windows primero
            $service = Get-Service -Name "nginx" -ErrorAction SilentlyContinue
            if ($service) {
                Restart-Service -Name "nginx" -Force
                Write-Host "✓ Nginx reiniciado (servicio)" -ForegroundColor Green
            } else {
                # Si no hay servicio, usar comando directo
                Push-Location $NginxPath
                
                # Detener Nginx
                & .\nginx.exe -s quit 2>&1 | Out-Null
                Start-Sleep -Seconds 2
                
                # Iniciar Nginx
                Start-Process -FilePath ".\nginx.exe" -WorkingDirectory $NginxPath -WindowStyle Hidden
                Start-Sleep -Seconds 2
                
                Pop-Location
                
                # Verificar si está corriendo
                $nginxProcess = Get-Process nginx -ErrorAction SilentlyContinue
                if ($nginxProcess) {
                    Write-Host "✓ Nginx reiniciado (proceso)" -ForegroundColor Green
                } else {
                    Write-Warning "No se pudo verificar si Nginx está corriendo"
                }
            }
        } else {
            Write-Host "`n⚠ Para aplicar los cambios, reinicia Nginx:" -ForegroundColor Yellow
            Write-Host "  nginx -s reload" -ForegroundColor White
            Write-Host "  o" -ForegroundColor Gray
            Write-Host "  Restart-Service nginx" -ForegroundColor White
        }
        
        Write-Host ""
        return $true
        
    } catch {
        Write-Error "Error al configurar seguridad: $_"
        return $false
    }
}

function Setup-NginxService {
    param(
        [int]$Port = 80,
        [string]$HtmlPath = "C:\inetpub\wwwroot"
    )

    if (-not(Test-Port -Port $Port)) {
        Write-Host "Abortando instalacion..." -ForegroundColor red
        exit 1
    }

    $aux = Get-Service nginx -ErrorAction SilentlyContinue

    if ($aux -eq $null) {
        Write-Host "Se ha detectado que no se tiene instalado nginx, abortando instalacion..." -ForegroundColor Red
        exit 1
    }

    $version = choco list nginx | findstr "nginx"
    $version = $version -split " "

    $nginxPath = "C:\tools\nginx-$($version[1])"
    # Nota: Chocolatey suele instalarlo en C:\tools\nginx o C:\nginx
    
    # 2. Crear directorio de contenido si no existe
    if (!(Test-Path $HtmlPath)) {
        New-Item -ItemType Directory -Force -Path $HtmlPath
        "<h1>Nginx funcionando en Windows Server Core</h1>" | Out-File "$HtmlPath\index.html"
    }

    # 3. Configuración básica del puerto en nginx.conf
    $confPath = "$nginxPath\conf\nginx.conf"
    (Get-Content $confPath) -replace 'listen\s+\d+;', "listen $Port;" | Set-Content $confPath


    $plantilla = Formar-Plantilla -nombre "nginx" -version $version[1] -puerto $Port
    Set-Content -Value $plantilla -Path "$nginxPath\html\index.html"

    # 5. Iniciar el servicio y abrir firewall
    Restart-Service nginx
    if (Get-NetFirewallRule -DisplayName "Nginx-HTTP" -ErrorAction SilentlyContinue) {
        Remove-NetFirewallRule -DisplayName "Nginx-HTTP"
    }

    Set-NginxSecurity -NginxPath $nginxPath -SecurityHeaders -HideServerInfo -RestartService

    New-NetFirewallRule -DisplayName "Nginx-HTTP" -Direction Inbound -LocalPort $Port -Protocol TCP -Action Allow -LocalAddress Any

    Write-Host "¡Nginx está corriendo en el puerto $Port!" -ForegroundColor Green
}

function Set-IISSecurity {
    <#
    .SYNOPSIS
        Configura opciones de seguridad en IIS (Internet Information Services).
    
    .DESCRIPTION
        Aplica configuraciones de seguridad recomendadas en IIS incluyendo:
        - Deshabilitar métodos HTTP peligrosos (TRACE, DELETE, PUT, etc.)
        - Ocultar información del servidor (header "Server")
        - Configurar encabezados de seguridad
        - Request Filtering para mayor seguridad
    
    .PARAMETER SiteName
        Nombre del sitio web de IIS (por defecto: "Default Web Site").
    
    .PARAMETER DisabledMethods
        Métodos HTTP a deshabilitar. Por defecto: TRACE, TRACK, DELETE, PUT, OPTIONS
    
    .PARAMETER SecurityHeaders
        Si se especifica, agrega encabezados de seguridad.
    
    .PARAMETER HideServerInfo
        Si se especifica, oculta el header "Server" y otras cabeceras que exponen información.
    
    .PARAMETER CreateBackup
        Si se especifica, crea backup de configuración antes de modificarla.
    
    .PARAMETER ApplyGlobally
        Si se especifica, aplica configuración a nivel de servidor (todos los sitios).
    
    .EXAMPLE
        Set-IISSecurity
        Aplica configuración de seguridad básica al Default Web Site.
    
    .EXAMPLE
        Set-IISSecurity -SecurityHeaders -HideServerInfo
        Aplica todas las configuraciones de seguridad.
    
    .EXAMPLE
        Set-IISSecurity -SiteName "MiSitio" -DisabledMethods @("TRACE", "DELETE") -SecurityHeaders
        Configura seguridad para un sitio específico.
    
    .EXAMPLE
        Set-IISSecurity -ApplyGlobally -HideServerInfo -SecurityHeaders
        Aplica configuración a nivel de servidor (todos los sitios).
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SiteName = "Default Web Site",
        
        [Parameter(Mandatory = $false)]
        [string[]]$DisabledMethods = @("TRACE", "TRACK", "DELETE", "PUT", "OPTIONS"),
        
        [Parameter(Mandatory = $false)]
        [switch]$SecurityHeaders,
        
        [Parameter(Mandatory = $false)]
        [switch]$HideServerInfo,
        
        [Parameter(Mandatory = $false)]
        [switch]$CreateBackup = $true,
        
        [Parameter(Mandatory = $false)]
        [switch]$ApplyGlobally
    )
    
    try {
        Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║        CONFIGURACIÓN DE SEGURIDAD IIS                    ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
        
        # Verificar privilegios de administrador
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            Write-Error "Se requieren privilegios de administrador para configurar IIS"
            return $false
        }
        
        # Verificar que IIS está instalado
        $iisInstalled = Get-WindowsFeature -Name Web-Server -ErrorAction SilentlyContinue
        if (-not $iisInstalled -or $iisInstalled.InstallState -ne 'Installed') {
            Write-Error "IIS no está instalado en este servidor"
            Write-Host "`nPara instalar IIS ejecuta:" -ForegroundColor Yellow
            Write-Host "  Install-WindowsFeature -Name Web-Server -IncludeManagementTools" -ForegroundColor White
            return $false
        }
        
        # Importar módulo de IIS
        Import-Module WebAdministration -ErrorAction Stop
        
        # Verificar sitio web
        if (-not $ApplyGlobally) {
            $site = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
            if (-not $site) {
                Write-Error "No se encontró el sitio web: $SiteName"
                Write-Host "`nSitios disponibles:" -ForegroundColor Yellow
                Get-Website | Format-Table Name, State, PhysicalPath -AutoSize
                return $false
            }
            
            Write-Host "Sitio web: $SiteName" -ForegroundColor Green
            Write-Host "Ruta física: $($site.PhysicalPath)" -ForegroundColor Gray
            Write-Host ""
        } else {
            Write-Host "Aplicando configuración GLOBAL (todos los sitios)" -ForegroundColor Yellow
            Write-Host ""
        }
        
        # Determinar ruta de web.config
        if ($ApplyGlobally) {
            $configPath = "$env:SystemRoot\System32\inetsrv\config\applicationHost.config"
            $webConfigPath = $null
        } else {
            $webConfigPath = Join-Path $site.PhysicalPath "web.config"
        }
        
        # Crear backup
        if ($CreateBackup) {
            if ($ApplyGlobally) {
                $backupPath = "$configPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Copy-Item $configPath $backupPath
                Write-Host "✓ Backup de applicationHost.config creado: $backupPath" -ForegroundColor Green
            } elseif (Test-Path $webConfigPath) {
                $backupPath = "$webConfigPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Copy-Item $webConfigPath $backupPath
                Write-Host "✓ Backup de web.config creado: $backupPath" -ForegroundColor Green
            }
        }
        
        Write-Host "`nAplicando configuraciones de seguridad..." -ForegroundColor Cyan
        
        # ============================================
        # 1. Deshabilitar métodos HTTP peligrosos
        # ============================================
        if ($DisabledMethods.Count -gt 0) {
            Write-Host "`n1. Configurando Request Filtering (métodos HTTP)..." -ForegroundColor Yellow
            
            $filteringPath = if ($ApplyGlobally) { 
                "IIS:\" 
            } else { 
                "IIS:\Sites\$SiteName" 
            }
            
            foreach ($method in $DisabledMethods) {
                try {
                    # Verificar si ya está bloqueado
                    $existing = Get-WebConfigurationProperty -PSPath $filteringPath `
                                    -Filter "system.webServer/security/requestFiltering/verbs" `
                                    -Name "Collection" |
                                Where-Object { $_.verb -eq $method }
                    
                    if ($existing) {
                        Write-Host "  • $method ya está bloqueado" -ForegroundColor Gray
                    } else {
                        # Agregar verbo bloqueado
                        Add-WebConfigurationProperty -PSPath $filteringPath `
                            -Filter "system.webServer/security/requestFiltering/verbs" `
                            -Name "." `
                            -Value @{verb=$method; allowed="false"}
                        
                        Write-Host "  ✓ $method bloqueado" -ForegroundColor Green
                    }
                } catch {
                    Write-Warning "No se pudo bloquear ${method}: $_"
                }
            }
        }
        
        # ============================================
        # 2. Ocultar header "Server" y otras cabeceras
        # ============================================
        if ($HideServerInfo) {
            Write-Host "`n2. Ocultando información del servidor..." -ForegroundColor Yellow
            
            $configPath = if ($ApplyGlobally) {
                "IIS:\"
            } else {
                "IIS:\Sites\$SiteName"
            }
            
            # Remover header "Server"
            try {
                # Verificar si customHeaders existe
                $customHeaders = Get-WebConfigurationProperty -PSPath $configPath `
                    -Filter "system.webServer/httpProtocol/customHeaders" `
                    -Name "Collection" -ErrorAction SilentlyContinue
                
                # Remover header Server si existe
                $serverHeader = $customHeaders | Where-Object { $_.name -eq "Server" }
                if ($serverHeader) {
                    Remove-WebConfigurationProperty -PSPath $configPath `
                        -Filter "system.webServer/httpProtocol/customHeaders" `
                        -Name "." `
                        -AtElement @{name='Server'}
                }
                
                # Agregar header vacío para Server (lo oculta)
                Add-WebConfigurationProperty -PSPath $configPath `
                    -Filter "system.webServer/httpProtocol/customHeaders" `
                    -Name "." `
                    -Value @{name='Server'; value=''}
                
                Write-Host "  ✓ Header 'Server' configurado para ocultarse" -ForegroundColor Green
            } catch {
                Write-Warning "No se pudo configurar header 'Server': $_"
            }
            
            # Remover X-Powered-By
            try {
                Remove-WebConfigurationProperty -PSPath $configPath `
                    -Filter "system.webServer/httpProtocol/customHeaders" `
                    -Name "." `
                    -AtElement @{name='X-Powered-By'} `
                    -ErrorAction SilentlyContinue
                
                Write-Host "  ✓ Header 'X-Powered-By' removido" -ForegroundColor Green
            } catch {
                # Es normal que falle si no existe
            }
            
            # Ocultar versión de ASP.NET
            try {
                Set-WebConfigurationProperty -PSPath $configPath `
                    -Filter "system.web/httpRuntime" `
                    -Name "enableVersionHeader" `
                    -Value $false `
                    -ErrorAction SilentlyContinue
                
                Write-Host "  ✓ Versión de ASP.NET ocultada" -ForegroundColor Green
            } catch {
                Write-Host "  • enableVersionHeader no aplicable (sitio no ASP.NET)" -ForegroundColor Gray
            }
        }
        
        # ============================================
        # 3. Configurar encabezados de seguridad
        # ============================================
        if ($SecurityHeaders) {
            Write-Host "`n3. Configurando encabezados de seguridad..." -ForegroundColor Yellow
            
            $configPath = if ($ApplyGlobally) {
                "IIS:\"
            } else {
                "IIS:\Sites\$SiteName"
            }
            
            $securityHeadersConfig = @(
                @{name='X-Frame-Options'; value='SAMEORIGIN'; description='Prevención de clickjacking'},
                @{name='X-Content-Type-Options'; value='nosniff'; description='Prevención de MIME-sniffing'},
                @{name='X-XSS-Protection'; value='1; mode=block'; description='Protección XSS'},
                @{name='Content-Security-Policy'; value="default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';"; description='Política de seguridad de contenido'},
                @{name='Referrer-Policy'; value='strict-origin-when-cross-origin'; description='Política de referrer'},
                @{name='Permissions-Policy'; value='geolocation=(), microphone=(), camera=()'; description='Permisos del navegador'}
            )
            
            foreach ($header in $securityHeadersConfig) {
                try {
                    # Verificar si ya existe
                    $existing = Get-WebConfigurationProperty -PSPath $configPath `
                        -Filter "system.webServer/httpProtocol/customHeaders" `
                        -Name "Collection" |
                        Where-Object { $_.name -eq $header.name }
                    
                    if ($existing) {
                        # Actualizar valor existente
                        Set-WebConfigurationProperty -PSPath $configPath `
                            -Filter "system.webServer/httpProtocol/customHeaders/add[@name='$($header.name)']" `
                            -Name "value" `
                            -Value $header.value
                        
                        Write-Host "  • $($header.name) actualizado" -ForegroundColor Gray
                    } else {
                        # Agregar nuevo header
                        Add-WebConfigurationProperty -PSPath $configPath `
                            -Filter "system.webServer/httpProtocol/customHeaders" `
                            -Name "." `
                            -Value @{name=$header.name; value=$header.value}
                        
                        Write-Host "  ✓ $($header.name) configurado" -ForegroundColor Green
                    }
                } catch {
                    Write-Warning "No se pudo configurar $($header.name): $_"
                }
            }
        }
        
        # ============================================
        # 4. Configuraciones adicionales de seguridad
        # ============================================
        Write-Host "`n4. Aplicando configuraciones adicionales..." -ForegroundColor Yellow
        
        $configPath = if ($ApplyGlobally) { "IIS:\" } else { "IIS:\Sites\$SiteName" }
        
        # Configurar límites de peticiones
        try {
            Set-WebConfigurationProperty -PSPath $configPath `
                -Filter "system.webServer/security/requestFiltering/requestLimits" `
                -Name "maxAllowedContentLength" `
                -Value 10485760  # 10 MB
            
            Write-Host "  ✓ Límite de tamaño de petición configurado (10 MB)" -ForegroundColor Green
        } catch {
            Write-Host "  • Límite de petición no modificado" -ForegroundColor Gray
        }
        
        # Habilitar filtrado de caracteres peligrosos
        try {
            Set-WebConfigurationProperty -PSPath $configPath `
                -Filter "system.webServer/security/requestFiltering" `
                -Name "allowHighBitCharacters" `
                -Value $false
            
            Write-Host "  ✓ Filtrado de caracteres peligrosos habilitado" -ForegroundColor Green
        } catch {
            Write-Host "  • Filtrado de caracteres no modificado" -ForegroundColor Gray
        }
        
        # Deshabilitar directorio browsing
        try {
            Set-WebConfigurationProperty -PSPath $configPath `
                -Filter "system.webServer/directoryBrowse" `
                -Name "enabled" `
                -Value $false
            
            Write-Host "  ✓ Directory browsing deshabilitado" -ForegroundColor Green
        } catch {
            Write-Host "  • Directory browsing no modificado" -ForegroundColor Gray
        }
        
        # Mostrar resumen
        Write-Host "`n" + ("=" * 60) -ForegroundColor Green
        Write-Host "✓ CONFIGURACIÓN DE SEGURIDAD COMPLETADA" -ForegroundColor Green
        Write-Host ("=" * 60) -ForegroundColor Green
        
        Write-Host "`nConfiguraciones aplicadas:" -ForegroundColor Cyan
        if ($DisabledMethods.Count -gt 0) {
            Write-Host "  • Métodos HTTP bloqueados: $($DisabledMethods -join ', ')" -ForegroundColor White
        }
        if ($HideServerInfo) {
            Write-Host "  • Header 'Server' ocultado" -ForegroundColor White
            Write-Host "  • Header 'X-Powered-By' removido" -ForegroundColor White
        }
        if ($SecurityHeaders) {
            Write-Host "  • Encabezados de seguridad configurados (6 headers)" -ForegroundColor White
        }
        Write-Host "  • Request filtering habilitado" -ForegroundColor White
        Write-Host "  • Directory browsing deshabilitado" -ForegroundColor White
        
        if ($ApplyGlobally) {
            Write-Host "`nÁmbito: GLOBAL (todos los sitios)" -ForegroundColor Yellow
        } else {
            Write-Host "`nSitio configurado: $SiteName" -ForegroundColor Cyan
        }
        
        Write-Host "`n⚠ IMPORTANTE: Reinicia el sitio web o pool de aplicaciones:" -ForegroundColor Yellow
        if ($ApplyGlobally) {
            Write-Host "  Restart-WebAppPool -Name DefaultAppPool" -ForegroundColor White
            Write-Host "  iisreset /restart" -ForegroundColor White
        } else {
            Write-Host "  Restart-WebAppPool -Name '$($site.applicationPool)'" -ForegroundColor White
            Write-Host "  Restart-WebItem 'IIS:\Sites\$SiteName'" -ForegroundColor White
        }
        
        Write-Host ""
        return $true
        
    } catch {
        Write-Error "Error al configurar seguridad: $_"
        return $false
    }
}

function Remove-IISServerHeader {
    <#
    .SYNOPSIS
        Remueve completamente el header "Server" de IIS.
    
    .DESCRIPTION
        Usa múltiples métodos para ocultar el header Server de IIS:
        1. URL Rewrite Module (outbound rules)
        2. Modificación del registro de Windows
        3. Custom headers
    
    .PARAMETER Method
        Método a usar: URLRewrite, Registry, Both (default: Both)
    
    .PARAMETER SiteName
        Nombre del sitio (default: "Default Web Site")
    
    .EXAMPLE
        Remove-IISServerHeader
        Usa ambos métodos para remover el header Server.
    
    .EXAMPLE
        Remove-IISServerHeader -Method URLRewrite
        Solo usa URL Rewrite Module.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("URLRewrite", "Registry", "Both")]
        [string]$Method = "Both",
        
        [Parameter(Mandatory = $false)]
        [string]$SiteName = "Default Web Site"
    )
    
    try {
        Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║        REMOVER HEADER 'SERVER' DE IIS                    ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
        
        # Verificar privilegios de administrador
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            Write-Error "Se requieren privilegios de administrador"
            return $false
        }
        
        Import-Module WebAdministration -ErrorAction Stop
        
        # ============================================
        # Método 1: URL Rewrite Module (RECOMENDADO)
        # ============================================
        if ($Method -eq "URLRewrite" -or $Method -eq "Both") {
            Write-Host "Método 1: Configurando URL Rewrite Module..." -ForegroundColor Cyan
            
            # Verificar si URL Rewrite está instalado
            $rewriteInstalled = Get-WebGlobalModule | Where-Object { $_.Name -eq "RewriteModule" }
            
            if (-not $rewriteInstalled) {
                Write-Host "  ⚠ URL Rewrite Module no está instalado" -ForegroundColor Yellow
                Write-Host "  Instalando URL Rewrite Module..." -ForegroundColor Cyan
                
                # Intentar instalar con Chocolatey
                $choco = Get-Command choco -ErrorAction SilentlyContinue
                if ($choco) {
                    choco install urlrewrite -y
                    Write-Host "  ✓ URL Rewrite Module instalado" -ForegroundColor Green
                } else {
                    Write-Host "  ⚠ No se pudo instalar automáticamente" -ForegroundColor Yellow
                    Write-Host "  Descarga manualmente desde: https://www.iis.net/downloads/microsoft/url-rewrite" -ForegroundColor Gray
                    
                    if ($Method -eq "URLRewrite") {
                        Write-Host "`n  Usa -Method Registry como alternativa" -ForegroundColor Yellow
                        return $false
                    }
                }
            } else {
                Write-Host "  ✓ URL Rewrite Module está instalado" -ForegroundColor Green
                
                # Configurar outbound rule para remover Server header
                $configPath = "IIS:\Sites\$SiteName"
                
                try {
                    # Limpiar reglas existentes con el mismo nombre
                    $existingRule = Get-WebConfigurationProperty -PSPath $configPath `
                        -Filter "system.webServer/rewrite/outboundRules/rule[@name='RemoveServerHeader']" `
                        -Name "." `
                        -ErrorAction SilentlyContinue
                    
                    if ($existingRule) {
                        Clear-WebConfiguration -PSPath $configPath `
                            -Filter "system.webServer/rewrite/outboundRules/rule[@name='RemoveServerHeader']"
                    }
                    
                    # Agregar regla para remover Server header
                    Add-WebConfigurationProperty -PSPath $configPath `
                        -Filter "system.webServer/rewrite/outboundRules" `
                        -Name "." `
                        -Value @{name='RemoveServerHeader'}
                    
                    Set-WebConfigurationProperty -PSPath $configPath `
                        -Filter "system.webServer/rewrite/outboundRules/rule[@name='RemoveServerHeader']" `
                        -Name "match" `
                        -Value @{serverVariable='RESPONSE_SERVER'; pattern='.+'}
                    
                    Set-WebConfigurationProperty -PSPath $configPath `
                        -Filter "system.webServer/rewrite/outboundRules/rule[@name='RemoveServerHeader']" `
                        -Name "action" `
                        -Value @{type='Rewrite'; value=''}
                    
                    Write-Host "  ✓ Outbound rule configurada para remover Server header" -ForegroundColor Green
                    
                } catch {
                    Write-Warning "No se pudo configurar URL Rewrite: $_"
                }
            }
        }
        
        # ============================================
        # Método 2: Modificación del Registro
        # ============================================
        if ($Method -eq "Registry" -or $Method -eq "Both") {
            Write-Host "`nMétodo 2: Modificando registro de Windows..." -ForegroundColor Cyan
            
            $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\HTTP\Parameters"
            
            try {
                # Crear entrada DisableServerHeader si no existe
                $disableServerHeader = Get-ItemProperty -Path $registryPath -Name "DisableServerHeader" -ErrorAction SilentlyContinue
                
                if (-not $disableServerHeader) {
                    New-ItemProperty -Path $registryPath -Name "DisableServerHeader" -Value 1 -PropertyType DWORD -Force | Out-Null
                    Write-Host "  ✓ DisableServerHeader creado en el registro" -ForegroundColor Green
                } else {
                    Set-ItemProperty -Path $registryPath -Name "DisableServerHeader" -Value 1
                    Write-Host "  ✓ DisableServerHeader actualizado en el registro" -ForegroundColor Green
                }
                
                Write-Host "  ⚠ IMPORTANTE: Se requiere reiniciar el servidor para aplicar cambios del registro" -ForegroundColor Yellow
                
            } catch {
                Write-Warning "No se pudo modificar el registro: $_"
            }
        }
        
        # ============================================
        # Limpiar headers incorrectos
        # ============================================
        Write-Host "`nLimpiando configuración de headers..." -ForegroundColor Cyan
        
        $configPath = "IIS:\Sites\$SiteName"
        
        # Remover headers "Server" mal configurados
        try {
            $customHeaders = Get-WebConfigurationProperty -PSPath $configPath `
                -Filter "system.webServer/httpProtocol/customHeaders" `
                -Name "Collection"
            
            # Remover cualquier header "Server" en customHeaders
            $serverHeaders = $customHeaders | Where-Object { $_.name -eq "Server" }
            foreach ($header in $serverHeaders) {
                Remove-WebConfigurationProperty -PSPath $configPath `
                    -Filter "system.webServer/httpProtocol/customHeaders" `
                    -Name "." `
                    -AtElement @{name='Server'} `
                    -ErrorAction SilentlyContinue
                
                Write-Host "  ✓ Header 'Server' removido de customHeaders" -ForegroundColor Green
            }
            
        } catch {
            Write-Host "  • No se encontraron headers 'Server' en customHeaders" -ForegroundColor Gray
        }
        
        # Verificar y corregir X-Frame-Options
        try {
            $xframeHeader = $customHeaders | Where-Object { $_.name -eq "X-Frame-Options" }
            if (-not $xframeHeader) {
                # Agregar X-Frame-Options si no existe
                Add-WebConfigurationProperty -PSPath $configPath `
                    -Filter "system.webServer/httpProtocol/customHeaders" `
                    -Name "." `
                    -Value @{name='X-Frame-Options'; value='SAMEORIGIN'}
                
                Write-Host "  ✓ X-Frame-Options configurado correctamente" -ForegroundColor Green
            }
        } catch {
            Write-Host "  • X-Frame-Options ya configurado" -ForegroundColor Gray
        }
        
        # Resumen
        Write-Host "`n" + ("=" * 60) -ForegroundColor Green
        Write-Host "✓ CONFIGURACIÓN COMPLETADA" -ForegroundColor Green
        Write-Host ("=" * 60) -ForegroundColor Green
        
        Write-Host "`nPróximos pasos:" -ForegroundColor Cyan
        
        if ($Method -eq "URLRewrite" -or $Method -eq "Both") {
            Write-Host "  1. Reiniciar sitio web:" -ForegroundColor White
            Write-Host "     Restart-WebItem 'IIS:\Sites\$SiteName'" -ForegroundColor Gray
        }
        
        if ($Method -eq "Registry" -or $Method -eq "Both") {
            Write-Host "  2. Reiniciar el servidor (para aplicar cambios del registro):" -ForegroundColor Yellow
            Write-Host "     Restart-Computer -Force" -ForegroundColor Gray
            Write-Host "     O reinicia manualmente" -ForegroundColor Gray
        }
        
        Write-Host "`n  3. Verificar con:" -ForegroundColor White
        Write-Host "     curl -I http://localhost" -ForegroundColor Gray
        
        Write-Host ""
        return $true
        
    } catch {
        Write-Error "Error al remover header Server: $_"
        return $false
    }
}