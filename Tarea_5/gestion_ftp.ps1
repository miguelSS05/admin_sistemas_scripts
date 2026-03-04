param (
    [string] $option,
    [switch] $install,
    [switch] $help,
    [switch] $confirm,
    [int] $no_users,
    [array] $users,
    [array] $passwords,
    [array] $groups
)

. ../Funciones/power_fun_par.ps1


$helpM="--- Opciones ---`n`n"
$helpM="${helpM}1) Instalar servicio FTP`n"
$helpM="${helpM}2) Verificar existencia del servicio FTP`n"
$helpM="${helpM}3) Desinstalar servicio FTP`n" # Verificar sintaxis y ver estado del servicio
$helpM="${helpM}4) Estatus servicio FTP`n"
$helpM="${helpM}5) Agregar usuarios`n"
$helpM="${helpM}6) Cambiar usuarios de grupo`n"
$helpM="${helpM}--- Banderas ---`n`n"
$helpM="${helpM}-help (mostrar este mensaje)`n"
$helpM="${helpM}-option (seleccionar opcion)`n"
$helpM="${helpM}-install (confirmar instalacion)`n"
$helpM="${helpM}-no_users (numero de usuarios a registrar)`n" # Verificar sintaxis y ver estado del servicio
$helpM="${helpM}-users (lista de usuarios separados por una coma | nombre de usuario para cambiarlo de grupo)`n"
$helpM="${helpM}-passwords (lista de contrase�as separadas por una coma)`n"
$helpM="${helpM}-groups (grupo al que pertenece separado por comas [1: reprobados | 2: recursadores])`n"

if ($help) {
    Write-Host $helpM
    exit 1
}

$color="yellow"
$ipLocal=""

function checkService {
	$aux = Get-Service -Name "FTPSVC" -ErrorAction SilentlyContinue

	if ($aux -eq $null) {
		Write-Host "Se ha detectado que no se tiene instalado el servicio FTPSVC" -Foregroundcolor "red"
	} else {
        Write-Host "Se ha detectado el servicio FTPSVC instalado" -Foreground $color
    } 
}

function installService {
	$aux = Get-Service -Name "FTPSVC" -ErrorAction SilentlyContinue

	if ($aux -eq $null) {
        Write-Host "Se ha detectado que no se tiene instalado el FTPSVC Server" -Foregroundcolor "red"

        if ($install) {
            Write-Host "Iniciando instalacion..." -Foregroundcolor $color
		    Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools	
		    Write-Host "La instalacion ha finalizado correctamente" -Foregroundcolor "green"   
        } else {
            Write-Host "Use la bandera -install para activar la instalacion" -ForegroundColor $color
        }

	} else {
        Write-Host "Se ha detectado el servicio FTPSVC instalado" -Foreground $color
    } 
}

function uninstallService {
	$aux = Get-Service -Name "FTPSVC" -ErrorAction SilentlyContinue

	if ($aux -eq $null) {
        Write-Host "Se ha detectado que no se tiene instalado el servicio FTPSVC" -Foregroundcolor "red"

	} else {
        Write-Host "Se ha detectado el servicio FTPSVC instalado" -Foreground $color

        if ($confirm) {
            Write-Host "Iniciando desinstalacion..." -Foregroundcolor $color
            Uninstall-WindowsFeature -Name Web-FTP-Server, Web-FTP-Ext	
		    Write-Host "La desinstalacion ha finalizado correctamente" -Foregroundcolor red   
        } else {
            Write-Host "Use la bandera -c para confirmar " -ForegroundColor $color
        }
    } 
}
function changeGroup {
    validateEmpty $users
    validateEmpty $groups

    $Ruta="C:\FTP"
    $RutaLocalUser = "$Ruta\LocalUser"
    $RutaUsuario = "$RutaLocalUser\$users"

    # Eliminar grupos a los que pertenecia antes el usuario
    Get-LocalGroup | Where-Object { `
    (Get-LocalGroupMember -Group $_.Name -ErrorAction SilentlyContinue).Name -match $users `
    } | ForEach-Object {Remove-LocalGroupMember -Member $users -Group $_.Name}

    if ( "$groups" -eq "1" ) {
        if (-not (Test-Path -Path "$RutaUsuario\Reprobados")) { New-Item -ItemType Junction -Path "$RutaUsuario\Reprobados" -Target "$Ruta\Reprobados" -Force | Out-Null }
        if (Test-Path -Path "$RutaUsuario\Recursadores") { Remove-Item -Path "$RutaUsuario\Recursadores" -Recurse -Confirm:$false | Out-Null }

        icacls "$RutaUsuario\Reprobados" /inheritance:r /grant "Administrators:(OI)(CI)F" /grant "SYSTEM:(OI)(CI)F" /grant "Reprobados:(OI)(CI)M" /T /C /Q 
        #icacls "$RutaUsuario\Reprobados" /grant "Authenticated Users:(OI)(CI)(M)" /C /Q

        Add-LocalGroupMember -Group "Reprobados" -Member "$users"
        Write-Host "Se ha cambiando el grupo del usuario a Reprobados" -Foregroundcolor green
    } elseif ( "$groups" -eq "2") {
        if (-not (Test-Path -Path "$RutaUsuario\Recursadores")) { New-Item -ItemType Junction -Path "$RutaUsuario\Recursadores" -Target "$Ruta\Recursadores" -Force | Out-Null }
        if (Test-Path -Path "$RutaUsuario\Reprobados") { Remove-Item -Path "$RutaUsuario\Reprobados" -Recurse -Confirm:$false | Out-Null }

        icacls "$RutaUsuario\Recursadores" /inheritance:r /grant "Administrators:(OI)(CI)F" /grant "SYSTEM:(OI)(CI)F" /grant "Recursadores:(OI)(CI)M" /T /C /Q
        #icacls "$RutaUsuario\Recursadores" /grant "Authenticated Users:(OI)(CI)(M)" /C /Q 

        Add-LocalGroupMember -Group "Recursadores" -Member "$users"
        Write-Host "Se ha cambiando el grupo del usuario a Recursadores" -Foregroundcolor green
    } else {
        Write-Host "Se ha detectado una opcion invalida de grupo" -Foregroundcolor red
    }
}

function UserExist {
    param (
        [string] $nombre
    )

    $aux = Get-LocalUser -Name "$nombre" -ErrorAction SilentlyContinue

    if ($null -ne $aux) {
        return $true;
    } else {
        return $false;
    }
}

function deleteUser {
    param (
        [string] $nombre
    )
    
    if (UserExist -nombre $nombre) {
        Remove-LocalUser -Name "$nombre"
    }

    if (UserExist -nombre $nombre) {
        Write-Host ""
        Remove-LocalUser -Name "$nombre"
    }
}

function validateUserName {
    param ([string]$userName)
    
    # Regla: No puede estar vacío y debe tener entre 3 y 20 caracteres
    if ($userName.Length -lt 3 -or $userName.Length -gt 20) {
        Write-Host "Error: El usuario '$userName' debe tener entre 3 y 20 caracteres." -ForegroundColor Red
        return $false
    }

    # Regla: No caracteres especiales prohibidos por Windows
    if ($userName -match '[\\/\[\]:;|=,+*?<>]') {
        Write-Host "Error: El usuario '$userName' contiene caracteres no permitidos." -ForegroundColor Red
        return $false
    }

    return $true
}

function validatePassword {
    param ([string]$password)

    $isStrong = $true
    $msg = ""

    if ($password.Length -lt 8) { $isStrong = $false; $msg += " - Mínimo 8 caracteres.`n" }
    if ($password -notmatch '[A-Z]') { $isStrong = $false; $msg += " - Al menos una mayúscula.`n" }
    if ($password -notmatch '[0-9]') { $isStrong = $false; $msg += " - Al menos un número.`n" }
    if ($password -notmatch '[\W_]') { $isStrong = $false; $msg += " - Al menos un carácter especial.`n" }

    if (-not $isStrong) {
        Write-Host "Contraseña inválida. Debe cumplir:`n$msg" -ForegroundColor Red
        return $false
    }

    return $true
}

function addUsers {
    $Ruta="C:\FTP"
    $users = $users -split ","
    $passwords = $passwords -split ","
    $groups = $groups -split ","

    if ($users.Length -ne $no_users -or $passwords.Length -ne $no_users -or $groups.Length -ne $no_users) {
        Write-Host "El número de usuarios, contraseñas y grupos debe coincidir con -no_users" -ForegroundColor red
        exit 1
    }

    validateEmptyArray $users
    validateEmptyArray $passwords
    validateEmptyArray $groups

    validateGroupNumber $groups 
    validateUserCreated $users 

    # 1. Crear la carpeta maestra de aislamiento obligatoria de IIS
    $RutaLocalUser = "$Ruta\LocalUser"
    if (-not (Test-Path -Path $RutaLocalUser)) { New-Item -Path $RutaLocalUser -ItemType Directory -Force | Out-Null }

    for($i=0; $i -lt $no_users; $i++) {
        $aux = ConvertTo-SecureString -String "$($passwords[$i])" -AsPlainText -Force
        New-LocalUser -Name "$($users[$i])" -Password $aux -PasswordNeverExpires | Out-Null

        # 2. La nueva ruta del usuario ahora estará enjaulada
        $RutaUsuario = "$RutaLocalUser\$($users[$i])"

        if (-not (Test-Path -Path "$RutaUsuario")) {
            New-Item -Path "$RutaUsuario" -ItemType Directory -Force | Out-Null
        }

        # 3. Permisos de su jaula personal (Solo el usuario, SYSTEM y Admin entran)
        icacls $RutaUsuario /inheritance:r /grant "$($users[$i]):(OI)(CI)F" /grant "Administrators:(OI)(CI)F" /grant "SYSTEM:(OI)(CI)F" /T /C /Q

        # 4. IMPLEMENTAR LOS "MOUNTS" (Junctions) hacia las carpetas compartidas
        if (-not (Test-Path -Path "$RutaUsuario\Publica")) { New-Item -ItemType Junction -Path "$RutaUsuario\Publica" -Target "$Ruta\Publica" -Force | Out-Null }

        # 5. Asignar el usuario a su grupo
        if ( "$($groups[$i])" -eq "1" ) {
            if (-not (Test-Path -Path "$RutaUsuario\Reprobados")) { New-Item -ItemType Junction -Path "$RutaUsuario\Reprobados" -Target "$Ruta\Reprobados" -Force | Out-Null }
            Add-LocalGroupMember -Group "Reprobados" -Member "$($users[$i])"
            Add-LocalGroupMember -Group "Users" -Member "$($users[$i])"
        } elseif ( "$($groups[$i])" -eq "2" ) {
            if (-not (Test-Path -Path "$RutaUsuario\Recursadores")) { New-Item -ItemType Junction -Path "$RutaUsuario\Recursadores" -Target "$Ruta\Recursadores" -Force | Out-Null }
            Add-LocalGroupMember -Group "Recursadores" -Member "$($users[$i])"
            Add-LocalGroupMember -Group "Users" -Member "$($users[$i])"
        }

        # 6. Crear la carpeta personal
        if (-not (Test-Path -Path "$RutaUsuario\$($users[$i])")) { New-Item -ItemType Directory -Path "$RutaUsuario\$($users[$i])" -Force | Out-Null }
    }

    Write-Host "Se ha terminado de añadir a los usuarios correctamente." -Foregroundcolor green
}

# function configureService {
# 	$aux = Get-Service -Name "FTPSVC" -ErrorAction SilentlyContinue

# 	if ($aux -eq $null) {
#         exit 1
# 	}

#     $Name="FTP Service"
#     $Ruta="C:\FTP"
#     $CarpetaA="$Ruta\Reprobados"
#     $CarpetaB="$Ruta\Recursadores"
#     $CarpetaC="$Ruta\Publica"

#     # Crear la carpeta
#     New-Item -Path $Ruta -ItemType Directory -Force    

#     # Creación del sitio FTP
#     New-WebFtpSite -Name $Name -Port 21 -PhysicalPath $Ruta -Force

#     # Creación de grupos
#     $aux = Get-LocalGroup | findstr "Reprobados"

#     if($aux -eq $null) {
#         New-LocalGroup -Name "Reprobados" -Description "Reprobados"
#     } 

#     $aux = Get-LocalGroup | findstr "Recursadores"

#     if($aux -eq $null) {
#         New-LocalGroup -Name "Recursadores" -Description "Recursadores"
#     }

# # 1. Borrar el archivo maldito para que deje de estorbar
#     if (Test-Path "$Ruta\web.config") { 
#         Remove-Item "$Ruta\web.config" -Force -ErrorAction SilentlyContinue 
#     }

#     # 2. Limpiar cualquier regla previa apuntando al cerebro central de IIS
#     Clear-WebConfiguration -Filter /system.ftpServer/security/authorization -PSPath "IIS:\" -Location $Name -ErrorAction SilentlyContinue

#     # 3. Añadir permisos apuntando al cerebro central (usando -Location $Name)
#     Add-WebConfiguration -Filter /system.ftpServer/security/authorization -PSPath "IIS:\" -Location $Name -Value @{accessType="Allow"; users="?"; permissions="Read"}

#     Add-WebConfiguration -Filter /system.ftpServer/security/authorization -PSPath "IIS:\" -Location $Name -Value @{accessType="Allow"; users="*"; permissions="Read"}

#     Add-WebConfiguration -Filter /system.ftpServer/security/authorization -PSPath "IIS:\" -Location $Name -Value @{accessType="Allow"; roles="Reprobados, Recursadores"; permissions="Read, Write"}

#     # 2. Rompemos la herencia de la raíz
#     icacls $Ruta /inheritance:r /C /Q

#     # 3. Damos permisos totales al Sistema y Administradores (para que PowerShell no falle)
#     icacls $Ruta /grant "Administrators:(OI)(CI)F" /C /Q
#     icacls $Ruta /grant "SYSTEM:(OI)(CI)F" /C /Q

#     # 4. Le damos permiso a IIS para que pueda leer su configuración
#     icacls $Ruta /grant "IIS_IUSRS:(OI)(CI)RX" /C /Q

#     # 5. Permisos de lectura base para usuarios anónimos y registrados
#     icacls $Ruta /grant "IUSR:(OI)(CI)RX" /C /Q
#     icacls $Ruta /grant "Authenticated Users:(OI)(CI)RX" /C /Q

#     # Permitir acceso anónimo
#     Set-ItemProperty "IIS:\Sites\$Name" -Name "ftpServer.security.authentication.anonymousAuthentication.enabled" -Value $true

#     # Habilitar autenticación básica
#     Set-ItemProperty "IIS:\Sites\$Name" -Name "ftpServer.security.authentication.basicAuthentication.enabled" -Value $true

#     # Dar permisos de lectura y escritura a todos los usuarios de Windows (*)
#     Add-WebConfiguration -Filter /system.ftpServer/security/authorization -PSPath "IIS:\Sites\$Name" -Value @{accessType="Allow"; users="*"; permissions="Read, Write"} 

#     $aux = Get-NetFirewallRule -Name "Regla_FTP_In" -ErrorAction SilentlyContinue

#     if ($aux -eq $null) {
#         New-NetFirewallRule -Name "Regla_FTP_In" -DisplayName "Permitir FTP (Puerto 21)" -Direction Inbound -Protocol TCP -LocalPort 21 -Action Allow
#     }

#     if (-not (Test-Path -Path "$CarpetaA" -PathType Container)) {
#         New-Item -Path "$CarpetaA" -ItemType Directory -Force
#     }

#     if (-not (Test-Path -Path "$CarpetaB" -PathType Container)) {
#         New-Item -Path "$CarpetaB" -ItemType Directory -Force
#     }

#     if (-not (Test-Path -Path "$CarpetaC" -PathType Container)) {
#         New-Item -Path "$CarpetaC" -ItemType Directory -Force
#     }



#     # 1. Configurar Carpeta A (Solo Grupo A, Administradores y Sistema)
#     icacls $CarpetaA /inheritance:r /T /C /Q  # Rompe la herencia
#     icacls $CarpetaA /grant "Reprobados:(OI)(CI)M" /T /C /Q # 'M' es permiso de Modificar (Lectura/Escritura)
#     icacls $CarpetaA /grant "Administrators:(OI)(CI)F" /T /C /Q # 'F' es Control Total
#     icacls $CarpetaA /grant "SYSTEM:(OI)(CI)F" /T /C /Q

#     # 2. Configurar Carpeta B (Solo Grupo B, Administradores y Sistema)
#     icacls $CarpetaB /inheritance:r /T /C /Q
#     icacls $CarpetaB /grant "Recursadores:(OI)(CI)M" /T /C /Q
#     icacls $CarpetaB /grant "Administrators:(OI)(CI)F" /T /C /Q
#     icacls $CarpetaB /grant "SYSTEM:(OI)(CI)F" /T /C /Q

#     # 1. Romper la herencia de la carpeta
#     icacls $CarpetaC /inheritance:r /T /C /Q

#     # 2. Permisos base para el sistema y administradores (Control Total)
#     icacls $CarpetaC /grant "Administrators:(OI)(CI)F" /T /C /Q
#     icacls $CarpetaC /grant "SYSTEM:(OI)(CI)F" /T /C /Q

#     # 3. Permiso de SOLO LECTURA para el usuario anónimo
#     icacls $CarpetaC /grant "IUSR:(OI)(CI)R" /T /C /Q

#     # 4. Permiso de LECTURA Y ESCRITURA para cualquier usuario que inicie sesión
#     icacls $CarpetaC /grant "Authenticated Users:(OI)(CI)M" /T /C /Q

#     Add-WebConfiguration -Filter /system.ftpServer/security/authorization -PSPath "IIS:\Sites\$Name" -Value @{accessType="Allow"; users="*"; permissions="Read, Write"} -ErrorAction SilentlyContinue

#     Import-Module WebAdministration

#     # 1. Crear un certificado SSL auto-firmado
#     $Cert = New-SelfSignedCertificate -DnsName "MiServidorFTP" -CertStoreLocation "cert:\LocalMachine\My"

#     # 2. Asignar el certificado al servidor FTP usando su "huella digital" (Thumbprint)
#     Set-ItemProperty -Path "IIS:\Sites\$Name" -Name "ftpServer.security.ssl.serverCertHash" -Value $Cert.Thumbprint

#     # 3. Obligar al servidor a requerir SSL para todo
#     Set-ItemProperty -Path "IIS:\Sites\$Name" -Name "ftpServer.security.ssl.controlChannelPolicy" -Value "SslRequire"
#     Set-ItemProperty -Path "IIS:\Sites\$Name" -Name "ftpServer.security.ssl.dataChannelPolicy" -Value "SslRequire"
#     Set-ItemProperty -Path "IIS:\Sites\$Name" -Name "ftpServer.userIsolation.mode" -Value "None"
    
#     # 1. Limpiar cualquier regla previa que pudiera existir en esa carpeta específica
#     Clear-WebConfiguration -Filter /system.ftpServer/security/authorization -PSPath "IIS:\Sites\$Name" -ErrorAction SilentlyContinue

#     # 2. Permitir Leer a los usuarios anónimos
#     Add-WebConfiguration -Filter /system.ftpServer/security/authorization -PSPath "IIS:\Sites\$Name" -Value @{accessType="Allow"; users="?"; permissions="Read"}

#     # 3. Permitir Leer y Escribir a los usuarios autenticados
#     Add-WebConfiguration -Filter /system.ftpServer/security/authorization -PSPath "IIS:\Sites\$Name" -Value @{accessType="Allow"; users="*"; permissions="Read, Write"}

#     Add-WebConfiguration -Filter /system.ftpServer/security/authorization -PSPath "IIS:\Sites\$Name" -Value @{accessType="Allow"; roles="Reprobados, Recursadores"; permissions="Read, Write"} 
    
#     Restart-WebItem "IIS:\Sites\$Name"
# }
function configureService {
    $aux = Get-Service -Name "FTPSVC" -ErrorAction SilentlyContinue

    if ($aux -eq $null) {
        exit 1
    }

    $Name="FTP Service"
    $Ruta="C:\FTP"
    $Anonymous="$Ruta\Anonymous"
    $RutaLocalUser = "$Ruta\LocalUser"
    $AnonymousJunction="$RutaLocalUser\Public\Publica"
    $CarpetaA="$Ruta\Reprobados"
    $CarpetaB="$Ruta\Recursadores"
    $CarpetaC="$Ruta\Publica"

    Write-Host "Preparando estructura de directorios..." -ForegroundColor Cyan

    # 1. Crear las carpetas si no existen
    if (-not (Test-Path -Path $Ruta)) { New-Item -Path $Ruta -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path -Path $CarpetaA)) { New-Item -Path $CarpetaA -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path -Path $CarpetaB)) { New-Item -Path $CarpetaB -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path -Path $CarpetaC)) { New-Item -Path $CarpetaC -ItemType Directory -Force | Out-Null }

    #1.1 Crear carpeta para aislamiento de usuarios
    if (-not (Test-Path -Path $RutaLocalUser)) { New-Item -Path $RutaLocalUser -ItemType Directory -Force | Out-Null }

    #1.2 Crear carpeta para anonymous
    if (-not (Test-Path -Path "$Anonymous")) { New-Item -Path "$Anonymous" -ItemType Directory -Force | Out-Null '.\Curso Bash.pdf'}
    if (-not (Test-Path -Path "$RutaLocalUser\Public")) { New-Item -Path "$RutaLocalUser\Public" -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path -Path "$AnonymousJunction")) { New-Item -ItemType Junction -Path "$AnonymousJunction" -Target "$Anonymous" -Force | Out-Null }

    # 2. ¡EL PASO CLAVE! Restaurar permisos a la normalidad para que IIS no se trabe por pruebas anteriores
    icacls $Ruta /reset /T /C /Q > $null 2>&1
    if (Test-Path "$Ruta\web.config") { Remove-Item "$Ruta\web.config" -Force -ErrorAction SilentlyContinue }

    Write-Host "Configurando el servicio IIS y FTP..." -ForegroundColor Cyan

    # 3. Creación de grupos
    if((Get-LocalGroup | findstr "Reprobados") -eq $null) { New-LocalGroup -Name "Reprobados" -Description "Reprobados" | Out-Null} 
    if((Get-LocalGroup | findstr "Recursadores") -eq $null) { New-LocalGroup -Name "Recursadores" -Description "Recursadores" | Out-Null}

    # 4. Creación del sitio FTP en IIS
    Import-Module WebAdministration
    New-WebFtpSite -Name $Name -Port 21 -PhysicalPath $Ruta -Force | Out-Null

    # 5. Configuración de Autenticación y SSL
    Set-ItemProperty "IIS:\Sites\$Name" -Name "ftpServer.security.authentication.anonymousAuthentication.enabled" -Value $true > $null 2>&1
    Set-ItemProperty "IIS:\Sites\$Name" -Name "ftpServer.security.authentication.basicAuthentication.enabled" -Value $true > $null 2>&1
    Set-ItemProperty -Path "IIS:\Sites\$Name" -Name "ftpServer.userIsolation.mode" -Value "IsolateAllDirectories" > $null 2>&1

    $Cert = New-SelfSignedCertificate -DnsName "MiServidorFTP" -CertStoreLocation "cert:\LocalMachine\My"
    Set-ItemProperty -Path "IIS:\Sites\$Name" -Name "ftpServer.security.ssl.serverCertHash" -Value $Cert.Thumbprint > $null 2>&1
    Set-ItemProperty -Path "IIS:\Sites\$Name" -Name "ftpServer.security.ssl.controlChannelPolicy" -Value "SslRequire" > $null 2>&1
    Set-ItemProperty -Path "IIS:\Sites\$Name" -Name "ftpServer.security.ssl.dataChannelPolicy" -Value "SslRequire" > $null 2>&1

    # 6. Firewall
    if ((Get-NetFirewallRule -Name "Regla_FTP_In" -ErrorAction SilentlyContinue) -eq $null) {
        New-NetFirewallRule -Name "Regla_FTP_In" -DisplayName "Permitir FTP (Puerto 21)" -Direction Inbound -Protocol TCP -LocalPort 21 -Action Allow > $null 2>&1
    }

    Write-Host "Aplicando reglas de autorización de IIS..." -ForegroundColor Cyan

    # 7. Reglas de Autorización de IIS (Ahora se ejecutan sin error porque la carpeta no está bloqueada)
    Clear-WebConfiguration -Filter /system.ftpServer/security/authorization -PSPath "IIS:\" -Location $Name -ErrorAction SilentlyContinue
    #Add-WebConfiguration -Filter /system.ftpServer/security/authorization -PSPath "IIS:\" -Location $Name -Value @{accessType="Allow"; users="?"; permissions="Read"}
    Add-WebConfiguration -Filter /system.ftpServer/security/authorization -PSPath "IIS:\" -Location $Name -Value @{accessType="Allow"; users="*"; permissions="Read, Write"} > $null 2>&1
    Add-WebConfiguration -Filter "/system.ftpServer/security/authorization" -Value @{accessType="Allow"; users="anonymous"; permissions="Read"} -PSPath "IIS:\Sites\$Name" > $null 2>&1
    
    Write-Host "Aplicando candados de seguridad NTFS..." -ForegroundColor Cyan

    # 8. HASTA EL FINAL: Aseguramos la carpeta raíz
    icacls $Ruta /inheritance:r /C /Q > $null 2>&1
    icacls $Ruta /grant "Administrators:(OI)(CI)F" /C /Q > $null 2>&1
    icacls $Ruta /grant "SYSTEM:(OI)(CI)F" /C /Q > $null 2>&1
    icacls $Ruta /grant "IIS_IUSRS:(OI)(CI)RX" /C /Q > $null 2>&1
    icacls $Ruta /grant "IUSR:(OI)(CI)(RX)" /C /Q > $null 2>&1
    icacls $Ruta /grant "Authenticated Users:(OI)(CI)(RX)" /C /Q > $null 2>&1

    # "$RutaLocalUser\ftp" icacls "$RutaLocalUser\ftp"  /grant "IUSR:(OI)(CI)(RX)" /C /Q

    icacls $RutaLocalUser  /grant "Authenticated Users:(OI)(CI)(RX)" /C /Q > $null 2>&1
    icacls $RutaLocalUser  /grant "IUSR:(OI)(CI)(RX)" /C /Q > $null 2>&1

    icacls $Anonymous /grant "IUSR:(OI)(CI)(RX)" /T /C /Q > $null 2>&1
    icacls $AnonymousJunction /grant "IUSR:(OI)(CI)(RX)" /T /C /Q > $null 2>&1
    icacls "$RutaLocalUser\Public" /grant "IUSR:(OI)(CI)(RX)" /T /C /Q > $null 2>&1


# 9. HASTA EL FINAL: Aseguramos las subcarpetas (TODO EN UNA SOLA LÍNEA)
    icacls $CarpetaA /inheritance:r /grant "Administrators:(OI)(CI)F" /grant "SYSTEM:(OI)(CI)F" /grant "Reprobados:(OI)(CI)M" /T /C /Q > $null 2>&1
    icacls $CarpetaB /inheritance:r /grant "Administrators:(OI)(CI)F" /grant "SYSTEM:(OI)(CI)F" /grant "Recursadores:(OI)(CI)M" /T /C /Q > $null 2>&1
    icacls $CarpetaC /inheritance:r /grant "Administrators:(OI)(CI)F" /grant "SYSTEM:(OI)(CI)F" /grant "IUSR:(OI)(CI)R" /grant "Authenticated Users:(OI)(CI)M" /T /C /Q > $null 2>&1

    icacls $CarpetaA /deny "Recursadores:(OI)(CI)F" /T /C /Q > $null 2>&1
    icacls $CarpetaB /deny "Reprobados:(OI)(CI)F" /T /C /Q > $null 2>&1
    icacls $CarpetaA /deny "IUSR:(OI)(CI)F" /T /C /Q > $null 2>&1
    icacls $CarpetaB /deny "IUSR:(OI)(CI)F" /T /C /Q > $null 2>&1

    Restart-WebItem "IIS:\Sites\$Name"
    Write-Host "Configuración completada con éxito." -ForegroundColor Green
}

function monitoreo {
	$aux = Get-Service -Name "FTPSVC" -ErrorAction SilentlyContinue

	if ($aux -eq $null) {
		Write-Host "Se ha detectado que no se tiene instalado el DNS Server" -Foregroundcolor "red"
	} else {
        Write-Host "`n=== Estado del servicio ===" -ForegroundColor $color
        Get-Service -Name "FTPSVC" -ErrorAction SilentlyContinue | ft -Autosize
    } 
}

switch ($option) {
    "1" {installService; configureService; break;}
	"2" {checkService; break;}
	"3" {uninstallService; break;}
	"4" {monitoreo; break;}
    "5" {addUsers; break;}
    "6" {changeGroup break;}
	default {Write-Host "Se ha detectado una opcion invalida, vuelve a intentarlo" -Foregroundcolor red}
}