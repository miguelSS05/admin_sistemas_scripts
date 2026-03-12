function getText {
	param (
		[string]$text
	)

	$aux = Read-Host -Prompt $text 
	$aux = $aux.Trim()

	while ($aux -eq "") {
		Write-Host "`nSe ha detectado un espacio vacio, vuelva a intentarlo" -Foreground Red
		$aux = Read-Host -Prompt $text
		$aux = $aux.Trim()		
	}

	return $aux
}

function getLocalIp {
    $aux = Get-NetIPAddress -InterfaceAlias "red_sistemas" -AddressFamily "IPv4" | Select-Object IPAddress | findstr "^[0-9]"

    if (!($aux -match '^\s*(((10[0-9])|(1?[1-9]?[0-9])|(2[0-4][0-9])|(25[0-5]))\.){3}((10[0-9])|(1?[1-9]?[0-9])|(2[0-4][0-9])|(25[0-5]))\s*$')) {
		Write-Host "`nNo se ha detectado una IPv4 local válida" -Foreground Red
		return "0"
	}

    return $aux
}

function validateRange { # Entrada: 3 IPs | Verifica q la IP2 no se encuentre entre ambas
	param (
		[string]$ip1,
        [string]$ip2,
        [string]$ip3,
        [string]$text
	)    

    # Validar gateway se encuentra en el rango
    if ((compareIp $ip3 $ip1) -AND (compareIp $ip2 $ip3)) {
       Write-Host $text -ForegroundColor Red
       return $false
    }

    # Validar gateway es igual a la IP Inicial o IP Final
    if (($ip3 -eq $ip1) -OR ($ip3 -eq $ip2)) {
       Write-Host $text -ForegroundColor Red
       return $false
    }

    return $true
}

#Valida que no caiga en la primera/ultima IP
function validateIpHosts {
	param (
		[string]$ip,
        [string]$netmask
	)    

    $octets = $ip -split "\."

    if ($netmask -eq "255.255.255.0") {
        if($octets[3] -eq "0") {
            Write-Host "Se ha detectado que la ip es el primer host (.0), regresando al menu..."
            return $false
        } elseif ($octets[3] -eq "255") {
            Write-Host "Se ha detectado que la ip es el ultimo host (.255), regresando al menu..."
            return $false      
        }
    } elseif ($netmask -eq "255.255.0.0") {
        if (($octets[2] -eq "0") -AND ($octets[3] -eq "0")) {
            Write-Host "Se ha detectado que la ip es el primer host (.0.0), regresando al menu..."
            return $false
        } elseif (($octets[2] -eq "255") -AND ($octets[3] -eq "255")) {
            Write-Host "Se ha detectado que la ip es el ultimo host (.255.255), regresando al menu..."
            return $false      
        }    
    } elseif ($netmask -eq "255.0.0.0") {
        if (($octets[1] -eq "0") -AND ($octets[2] -eq "0") -AND ($octets[3] -eq "0")) {
            Write-Host "Se ha detectado que la ip es el primer host (.0.0.0), regresando al menu..."
            return $false
        } elseif (($octets[1] -eq "255") -AND ($octets[2] -eq "255") -AND ($octets[3] -eq "255")) {
            Write-Host "Se ha detectado que la ip es el ultimo host (.255.255.255), regresando al menu..."
            return $false       
        }    
    }

    return $true
}

function validateIp {
	param (
		[string]$text,
        [boolean]$opt
	)

	$aux = Read-Host -Prompt $text

    if ((($aux -eq "N") -or ($aux -eq "n")) -and ($opt -eq $true)) {return $aux}

	while (!($aux -match '^\s*(((10[0-9]|1?[1-9]?[0-9])|(2[0-4][0-9]|25[0-5]))\.){3}(((10[0-9]|1?[1-9]?[0-9])|(2[0-4][0-9]|25[0-5])))\s*$')) {
		Write-Host "`nNo se ha detectado el formato IPv4, vuelva a intentarlo" -Foreground Red
		$aux = Read-Host -Prompt $text
        if ((($aux -eq "N") -or ($aux -eq "n")) -and ($opt -eq $true)) {return $aux}
	}

	return $aux
}

function validateSegment1 {
    param (
        [string] $seg1,
        [string] $seg2,
        [string] $text
    )

    # Mismo segmento
    if ($seg1 -ne $seg2) {
        Write-Host $text -ForegroundColor Red
        Return $false
    }

    Return $true
}

function validateSegment2 {
    param (
        [string] $seg1,
        [string] $seg2,
        [string] $seg3,
        [string] $text
    )

    # Mismo segmento
    if (($seg1 -ne $seg2) -or ($seg3 -ne $seg2)) {
        Write-Host $text -ForegroundColor Red
        Return $false;
    }

    Return $true
}
 

function validateInt {
	param (
        [string]$text
	)

	$aux = Read-Host -Prompt $text

	while (!($aux -match '^\d+$')) {
		Write-Host "`nNo se ha detectado un numero sin signos (+ | -), vuelva a intentarlo" -Foreground Red
		$aux = Read-Host -Prompt $text 
	}

	return $aux
}

function banIp {
	param (
		[string]$ip
	)

    $octets = $ip -split "\."

    if ([int]$octets[0] -eq 0) {
        Write-Host "`nEl primer octeto no puede ser 0" -Foreground Red
        return $true;
    } elseif ([int]$octets[0] -eq 127) {
        Write-Host "`nEl primer octeto no puede ser 127" -Foreground Red
        return $true;
    #} elseif (([int]$octets[0] -eq 169) -AND ([int]$octets[1] -eq 254)) {
    #    Write-Host "`nLos primeros octetos no pueden ser 169.254" -Foreground Red
    #    return $true;
    } elseif ([int]$octets[0] -eq 255) { # Banear clase D y E inválidas
        Write-Host "`nEl primer octeto no puede ser 255" -Foreground Red
        return $true;
    }

    return $false;
}

function usableIp {
	param (
		[string]$text,
		[boolean]$opt
	)

	$aux = validateIp $text $opt

    if ((($aux -eq "N") -or ($aux -eq "n")) -and ($opt -eq $true)) {return ""}

	while (banIp $aux) {
		$aux = validateIp $text $opt

        if ((($aux -eq "N") -or ($aux -eq "n")) -and ($opt -eq $true)) {return ""}
	}

	return $aux
}

function getSegment {
	param (
		[string]$ip
	)

    $octets = $ip -split "\."

    $octet1 = [int]$octets[0]

    if (($octet1 -ge 1) -AND ($octet1 -le 126)) {
        return $octets[0]+".0.0.0"
    } elseif (($octet1 -ge 128) -AND ($octet1 -le 191)) {
        return $octets[0]+"."+$octets[1]+".0.0"
    } elseif (($octet1 -ge 192) -AND ($octet1 -le 223)) {
        return $octets[0]+"."+$octets[1]+"."+$octets[2]+".0"
    } else {
        # Nada
    }
}

function getNetmask {
	param (
		[string]$ip
	)

    $octets = $ip -split "\."

    $octet1 = [int]$octets[0]

    if (($octet1 -ge 1) -AND ($octet1 -le 126)) {
        return "255.0.0.0"
        Write-Host "Se ha detectado la clase A"
    } elseif (($octet1 -ge 128) -AND ($octet1 -le 191)) {
        return "255.255.0.0"
        Write-Host "Se ha detetado la clase B"
    } elseif (($octet1 -ge 192) -AND ($octet1 -le 223)) {
        return "255.255.255.0"
        Write-Host "Se ha detetado la clase C"
    } else {
        # Nada
    }
}

function validateTimeFormat {
	param (
		[string]$text
	)

	$aux = getText $text

	while (!($aux -match '^(\d+\.)?([0-1]?[0-9]|2[0-3]):[0-5]?[0-9](:[0-5]?[0-9])?$')) {
		Write-Host "`nNo se ha detectado un tiempo correto, formatos vÃ¡lidos: (D.)?HH:MM:SS | (D.)?H:M:S | (D.)?HH:MM | (D.)?H:M" -Foreground Red
		$aux = getText $text 
	}

	return $aux
}

function ConvertTo-IPv4Integer {
    param(
        [string]$IPv4Address
    )
            
    $ipAddress = [IPAddress]::Parse($IPv4Address)            
    $bytes = $ipAddress.GetAddressBytes()
    [Array]::Reverse($bytes)
    $value = [System.BitConverter]::ToUInt32($bytes, 0)

    return $value
} 

function CompareIp {
    param (
        [string]$ip1,
        [string]$ip2
    )
    
    $value1 = ConvertTo-IPv4Integer $ip1
    $value2 = ConvertTo-IPv4Integer $ip2

    if ($value1 -gt $value2) {
        return $true
    } else {
        return $false
    }
}

function getOne {
    param (
        [string] $ip
    )
    $octets = $ip -split "\."

    $octet1=[int]$octets[0]
    $octet2=[int]$octets[1]
    $octet3=[int]$octets[2]
    $octet4=[int]$octets[3]

    $octet4 = $octet4 + 1

    if ($octet4 -ge 256) {
        $octet3 = $octet3+1        
        $octet4 = 0
    }

    if ($octet3 -ge 256) {
        $octet2 = $octet2+1        
        $octet3 = 0
    }

    if ($octet2 -ge 256) {
        $octet1 = $octet1+1        
        $octet2 = 0
    }

    return [string]$octet1+"."+[string]$octet2+"."+[string]$octet3+"."+[string]$octet4

}

function getPrefix {
	param (
		[string]$ip
	)

    $octets = $ip -split "\."

    $octet1 = [int]$octets[0]

    if (($octet1 -ge 1) -AND ($octet1 -le 126)) {
        return "8"
    } elseif (($octet1 -ge 128) -AND ($octet1 -le 191)) {
        return "16"
    } elseif (($octet1 -ge 192) -AND ($octet1 -le 223)) {
        return "24"
    } else {
        # Nada
    }
}

function restartIp {
    param (
        [string]$ip
    )

    $prefix = getPrefix $ip
    Remove-NetIPAddress -InterfaceIndex 2 -Confirm:$false
    New-NetIPAddress -InterfaceIndex 2 -IPAddress $ip -PrefixLength $prefix -Confirm:$false > $null 2>&1
}

function Install-Chocolatey {
    param(
        [Parameter(Mandatory=$false)]
        [switch]$install
    )

    if ($install) {
        # Verificamos si ya está instalado para evitar el mensaje de advertencia que viste antes
        if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
            Write-Host "Iniciando instalación silenciosa de Chocolatey..." -ForegroundColor Cyan
            
            try {
                # Configuración de TLS 1.2 y ejecución del script oficial
                [System.Net.ServicePointManager]::SecurityProtocol = 3072
                $script = (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')
                
                # Ejecución con redirección de todos los flujos al vacío (*>$null)
                Invoke-Expression $script *>$null
                
                Write-Host "¡Chocolatey instalado con éxito!" -ForegroundColor Green
            }
            catch {
                Write-Error "Hubo un fallo durante la instalación: $_"
            }
        } 
        else {
            Write-Host "Chocolatey ya se encuentra instalado en este sistema." -ForegroundColor Yellow
        }
    } 
    else {
        Write-Host "Use el parámetro '-install' para proceder con la instalación." -ForegroundColor Magenta
    }
}

function VerifyServiceInstalation {
    param (
        [string]$nombre
    )

	$aux = Get-Service -Name $nombre -ErrorAction SilentlyContinue

	if ($aux -eq $null) {
		Write-Host "Se ha detectado que no se tiene instalado el servicio $nombre" -Foregroundcolor "red"
	} else {
        Write-Host "Se ha detectado el servicio $nombre instalado" -Foreground "yellow"
    } 
}

function GetServiceEstatus {
    param (
        [string]$nombre
    )

	$aux = Get-Service -Name $nombre -ErrorAction SilentlyContinue

	if ($aux -eq $null) {
		Write-Host "Se ha detectado que no se tiene instalado el servicio $nombre" -Foregroundcolor "red"
	} else {
        Write-Host "`n=== Estado del servicio ===" -ForegroundColor "yellow"
        Get-Service -Name $nombre -ErrorAction SilentlyContinue | ft -Autosize
    } 
}

function GetServiceExists {
    param (
        [string]$nombre
    )

	$aux = Get-Service -Name $nombre -ErrorAction SilentlyContinue

	if ($aux -eq $null) {
        return 0 # No se tiene instalado
	} else {
        return 1 # Esta instalado
    } 
}

function Get-ChocoPackageVersions {
    <#
    .SYNOPSIS
        Consulta todas las versiones disponibles de un paquete en Chocolatey.
    
    .DESCRIPTION
        Esta función ejecuta el comando 'choco search <PackageName> --all --exact' 
        y procesa los resultados para mostrar todas las versiones disponibles del paquete especificado.
    
    .PARAMETER PackageName
        El nombre exacto del paquete de Chocolatey a buscar.
    
    .PARAMETER ShowTable
        Si se especifica, muestra los resultados en formato de tabla automáticamente.
    
    .EXAMPLE
        Get-ChocoPackageVersions -PackageName "apache-httpd"
        Muestra todas las versiones disponibles de Apache HTTP Server.
    
    .EXAMPLE
        Get-ChocoPackageVersions -PackageName "nginx" -ShowTable
        Muestra todas las versiones de nginx en formato de tabla.
    
    .EXAMPLE
        Get-ChocoPackageVersions "nodejs" | Select-Object -First 10
        Muestra las 10 primeras versiones de Node.js.
    
    .EXAMPLE
        Get-ChocoPackageVersions "python" | Where-Object { $_.Version -like "3.11.*" }
        Filtra solo las versiones 3.11.x de Python.
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageName,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowTable
    )
    
    try {
        # Verificar si Chocolatey está instalado
        $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
        
        if (-not $chocoCmd) {
            Write-Error "Chocolatey no está instalado en este sistema. Por favor, instálalo desde https://chocolatey.org"
            return
        }
        
        Write-Verbose "Consultando versiones de '$PackageName' en Chocolatey..."
        
        # Ejecutar el comando de Chocolatey
        $chocoOutput = choco search $PackageName --all --exact 2>&1
        
        # Verificar si hubo errores
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error al ejecutar el comando de Chocolatey. Código de salida: $LASTEXITCODE"
            return
        }
        
        # Procesar la salida
        $versions = @()
        $inResults = $false
        
        foreach ($line in $chocoOutput) {
            # Convertir a string si no lo es
            $lineStr = $line.ToString()
            
            # Buscar el inicio de los resultados (línea que coincide con el nombre del paquete)
            if ($lineStr -match "^$PackageName\s+") {
                $inResults = $true
            }
            
            # Procesar líneas de versiones usando regex más flexible
            if ($inResults -and $lineStr -match "^$PackageName\s+([\d\.\-a-zA-Z]+)") {
                $version = $matches[1]
                
                $versionObj = [PSCustomObject]@{
                    Package = $PackageName
                    Version = $version
                    InstallCommand = "choco install $PackageName --version=$version -y"
                }
                
                $versions += $versionObj
            }
            
            # Detectar el fin de los resultados
            if ($lineStr -match "^\d+\s+packages found") {
                break
            }
        }
        
        if ($versions.Count -eq 0) {
            Write-Warning "No se encontraron versiones del paquete '$PackageName'. Verifica que el nombre sea correcto."
            Write-Host "`nPuedes buscar paquetes con: choco search $PackageName" -ForegroundColor Cyan
            return
        }
        
        Write-Host "`nSe encontraron $($versions.Count) versiones de '$PackageName':" -ForegroundColor Green
        
        # Si se especificó ShowTable, mostrar en formato tabla
        if ($ShowTable) {
            $versions | Format-Table -AutoSize
            Write-Host "`nPara instalar una versión específica, usa:" -ForegroundColor Cyan
            Write-Host "choco install $PackageName --version=<VERSION> -y" -ForegroundColor Yellow
        }
        else {
            return $versions
        }
        
    }
    catch {
        Write-Error "Ocurrió un error: $_"
        return
    }
}

function Install-ChocoPackage {
    <#
    .SYNOPSIS
        Instala un paquete de Chocolatey con opciones personalizables.
    
    .DESCRIPTION
        Esta función facilita la instalación de paquetes desde Chocolatey con soporte 
        para versiones específicas, instalación forzada y confirmación opcional.
    
    .PARAMETER PackageName
        El nombre del paquete a instalar.
    
    .PARAMETER Version
        Versión específica del paquete a instalar. Si no se especifica, instala la última versión.
    
    .PARAMETER Force
        Fuerza la reinstalación del paquete incluso si ya está instalado.
    
    .PARAMETER SkipConfirmation
        Omite la confirmación antes de instalar (usar con precaución).
    
    .PARAMETER AdditionalParams
        Parámetros adicionales para pasar a Chocolatey (ej: "--params", "--install-arguments").
    
    .EXAMPLE
        Install-ChocoPackage -PackageName "apache-httpd"
        Instala la última versión de Apache.
    
    .EXAMPLE
        Install-ChocoPackage -PackageName "nginx" -Version "1.24.0"
        Instala una versión específica de Nginx.
    
    .EXAMPLE
        Install-ChocoPackage "nodejs" -Force
        Reinstala Node.js forzadamente.
    
    .EXAMPLE
        Install-ChocoPackage "git" -SkipConfirmation
        Instala Git sin pedir confirmación.
    
    .EXAMPLE
        Install-ChocoPackage "python" -Version "3.11.0" -AdditionalParams "/InstallDir:C:\Python311"
        Instala Python con parámetros personalizados.
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PackageName,
        
        [Parameter(Mandatory = $false)]
        [string]$Version,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipConfirmation,
        
        [Parameter(Mandatory = $false)]
        [string]$AdditionalParams
    )
    
    try {
        # Verificar si Chocolatey está instalado
        $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
        
        if (-not $chocoCmd) {
            Write-Error "Chocolatey no está instalado. Instálalo desde https://chocolatey.org"
            return
        }
        
        # Verificar permisos de administrador
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            Write-Warning "Se recomienda ejecutar PowerShell como Administrador para instalar paquetes."
            Write-Host "¿Deseas continuar de todos modos? (S/N): " -NoNewline -ForegroundColor Yellow
            $response = Read-Host
            if ($response -notmatch '^[sS]$') {
                Write-Host "Instalación cancelada." -ForegroundColor Red
                return
            }
        }
        
        # Construir el comando de instalación
        $installCmd = "choco install $PackageName"
        
        if ($Version) {
            $installCmd += " --version=$Version"
        }
        
        if ($Force) {
            $installCmd += " --force"
        }
        
        # Siempre agregar -y para auto-confirmación de Chocolatey
        $installCmd += " -y"
        
        if ($AdditionalParams) {
            $installCmd += " $AdditionalParams"
        }
        
        # Mostrar información de lo que se va a instalar
        Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║           INSTALACIÓN DE PAQUETE CHOCOLATEY              ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host "`nPaquete:  " -NoNewline -ForegroundColor White
        Write-Host $PackageName -ForegroundColor Green
        
        if ($Version) {
            Write-Host "Versión:  " -NoNewline -ForegroundColor White
            Write-Host $Version -ForegroundColor Green
        } else {
            Write-Host "Versión:  " -NoNewline -ForegroundColor White
            Write-Host "Última disponible" -ForegroundColor Yellow
        }
        
        Write-Host "`nComando:  " -NoNewline -ForegroundColor White
        Write-Host $installCmd -ForegroundColor Gray
        
        # Confirmar instalación si no se especificó SkipConfirmation
        if (-not $SkipConfirmation) {
            Write-Host "`n¿Deseas proceder con la instalación? (S/N): " -NoNewline -ForegroundColor Yellow
            $confirm = Read-Host
            
            if ($confirm -notmatch '^[sS]$') {
                Write-Host "`nInstalación cancelada por el usuario." -ForegroundColor Red
                return
            }
        }
        
        # Ejecutar la instalación
        Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
        Write-Host "Iniciando instalación..." -ForegroundColor Green
        Write-Host ("=" * 60) -ForegroundColor Cyan
        Write-Host ""
        
        $output = Invoke-Expression $installCmd 2>&1
        
        # Mostrar el output de Chocolatey
        $output | ForEach-Object { Write-Host $_ }
        
        # Verificar el resultado
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n" + ("=" * 60) -ForegroundColor Green
            Write-Host "✓ Instalación completada exitosamente" -ForegroundColor Green
            Write-Host ("=" * 60) -ForegroundColor Green
            
            # Mostrar información post-instalación
            Write-Host "`nPara verificar la instalación, usa:" -ForegroundColor Cyan
            Write-Host "choco list --local-only $PackageName" -ForegroundColor White
        }
        else {
            Write-Host "`n" + ("=" * 60) -ForegroundColor Red
            Write-Host "✗ Error durante la instalación (Código: $LASTEXITCODE)" -ForegroundColor Red
            Write-Host ("=" * 60) -ForegroundColor Red
            Write-Error "La instalación falló. Revisa los mensajes anteriores."
        }
        
    }
    catch {
        Write-Error "Ocurrió un error inesperado: $_"
    }
}

function Test-Port {
    <#
    .SYNOPSIS
        Valida si un puerto es válido, no está reservado y no está en uso.
    
    .DESCRIPTION
        Verifica que un puerto esté en el rango válido (1-65535), 
        no sea un puerto reservado del sistema (1-1023), y 
        no esté siendo usado actualmente en el sistema.
    
    .PARAMETER Port
        El número de puerto a validar.
    
    .PARAMETER AllowReserved
        Si se especifica, permite usar puertos reservados (1-1023).
    
    .EXAMPLE
        Test-Port -Port 8080
        Valida si el puerto 8080 es válido, no reservado y está libre.
    
    .EXAMPLE
        Test-Port -Port 80 -AllowReserved
        Valida el puerto 80 permitiendo que sea reservado.
    
    .EXAMPLE
        if (Test-Port 3000) { "Puerto 3000 disponible" }
        Uso en condicional.
    #>
    
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [int]$Port
    )
    
    process {
        # 1. Validar rango (1-65535)
        if ($Port -lt 1 -or $Port -gt 65535) {
            Write-Host "✗ Puerto $Port fuera de rango válido (1-65535)" -ForegroundColor Red
            return $false
        }
        
        # 3. Verificar si está en uso
        $inUse = $false
        
        try {
            # Verificar conexiones TCP existentes
            $tcpConnections = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
            if ($tcpConnections) {
                $inUse = $true
                Write-Host "✗ Puerto $Port está en uso" -ForegroundColor Red
                
                # Mostrar qué proceso lo está usando
                foreach ($conn in $tcpConnections) {
                    $process = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
                    if ($process) {
                        Write-Host "  └─ Proceso: $($process.ProcessName) (PID: $($process.Id))" -ForegroundColor Yellow
                    }
                }
                return $false
            }
            
            # Verificar listeners UDP
            $udpEndpoints = Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue
            if ($udpEndpoints) {
                $inUse = $true
                Write-Host "✗ Puerto $Port está en uso (UDP)" -ForegroundColor Red
                
                foreach ($endpoint in $udpEndpoints) {
                    $process = Get-Process -Id $endpoint.OwningProcess -ErrorAction SilentlyContinue
                    if ($process) {
                        Write-Host "  └─ Proceso: $($process.ProcessName) (PID: $($process.Id))" -ForegroundColor Yellow
                    }
                }
                return $false
            }
            
        } catch {
            Write-Warning "No se pudo verificar si el puerto está en uso: $_"
        }
        
        # Si llegamos aquí, el puerto es válido
        Write-Host "✓ Puerto $Port disponible" -ForegroundColor Green
        return $true
    }
}

function Set-NtfsRule {
    param(
        [string]$Path,
        [string]$Identity,
        [string]$Rights,          # e.g. "FullControl","ReadAndExecute","Modify"
        [string]$Inheritance = "ContainerInherit,ObjectInherit",
        [string]$Propagation = "None",
        [string]$Type = "Allow"   # "Allow" | "Deny"
    )
    $acl   = Get-Acl -Path $Path
    $rule  = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $Identity, $Rights, $Inheritance, $Propagation, $Type)
    if ($Type -eq "Deny") { $acl.AddAccessRule($rule) }
    else                  { $acl.SetAccessRule($rule) }
    Set-Acl -Path $Path -AclObject $acl
}

function New-FirewallRule {
    <#
    .SYNOPSIS
        Crea una regla de firewall en Windows.
    
    .DESCRIPTION
        Crea una regla de firewall para permitir tráfico entrante en un puerto específico.
        Requiere privilegios de administrador.
    
    .PARAMETER DisplayName
        Nombre descriptivo para la regla del firewall.
    
    .PARAMETER Port
        Número de puerto a abrir (1-65535).
    
    .PARAMETER Protocol
        Protocolo de red (TCP o UDP).
    
    .PARAMETER Direction
        Dirección del tráfico (Inbound o Outbound). Por defecto: Inbound.
    
    .PARAMETER Action
        Acción a realizar (Allow o Block). Por defecto: Allow.
    
    .PARAMETER Profile
        Perfil de red (Domain, Private, Public, o Any). Por defecto: Any.
    
    .EXAMPLE
        New-FirewallRule -DisplayName "Mi Aplicación Web" -Port 8080 -Protocol TCP
        Crea una regla para permitir tráfico TCP en el puerto 8080.
    
    .EXAMPLE
        New-FirewallRule -DisplayName "Servidor DNS" -Port 53 -Protocol UDP
        Crea una regla para permitir tráfico UDP en el puerto 53.
    
    .EXAMPLE
        New-FirewallRule -DisplayName "API Server" -Port 3000 -Protocol TCP -Profile Private
        Crea una regla solo para redes privadas.
    
    .EXAMPLE
        New-FirewallRule -DisplayName "Block Port" -Port 445 -Protocol TCP -Action Block
        Crea una regla para bloquear un puerto.
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$DisplayName,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateRange(1, 65535)]
        [int]$Port,
        
        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateSet("TCP", "UDP", IgnoreCase = $true)]
        [string]$Protocol,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Inbound", "Outbound")]
        [string]$Direction = "Inbound",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Allow", "Block")]
        [string]$Action = "Allow",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Domain", "Private", "Public", "Any")]
        [string]$Profile = "Any"
    )
    
    try {
        # Verificar permisos de administrador
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            Write-Error "Esta función requiere privilegios de administrador. Ejecuta PowerShell como Administrador."
            return $false
        }
        
        # Normalizar protocolo a mayúsculas
        $Protocol = $Protocol.ToUpper()
        
        # Verificar si ya existe una regla con el mismo nombre
        $existingRule = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue
        
        if ($existingRule) {
            Write-Warning "Ya existe una regla con el nombre '$DisplayName'"
            Write-Host "¿Deseas eliminarla y crear una nueva? (S/N): " -NoNewline -ForegroundColor Yellow
            $response = Read-Host
            
            if ($response -match '^[sS]$') {
                Remove-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue
                Write-Host "Regla anterior eliminada." -ForegroundColor Yellow
            } else {
                Write-Host "Operación cancelada." -ForegroundColor Red
                return $false
            }
        }
        
        # Mostrar información de la regla a crear
        Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║           CREAR REGLA DE FIREWALL                        ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Nombre:        " -NoNewline -ForegroundColor White
        Write-Host $DisplayName -ForegroundColor Green
        Write-Host "Puerto:        " -NoNewline -ForegroundColor White
        Write-Host $Port -ForegroundColor Green
        Write-Host "Protocolo:     " -NoNewline -ForegroundColor White
        Write-Host $Protocol -ForegroundColor Green
        Write-Host "Dirección:     " -NoNewline -ForegroundColor White
        Write-Host $Direction -ForegroundColor Green
        Write-Host "Acción:        " -NoNewline -ForegroundColor White
        if ($Action -eq "Allow") {
            Write-Host $Action -ForegroundColor Green
        } else {
            Write-Host $Action -ForegroundColor Red
        }
        Write-Host "Perfil:        " -NoNewline -ForegroundColor White
        Write-Host $Profile -ForegroundColor Green
        Write-Host ""
        
        # Crear la regla de firewall
        Write-Host "Creando regla de firewall..." -ForegroundColor Cyan
        
        $ruleParams = @{
            DisplayName = $DisplayName
            Direction   = $Direction
            Protocol    = $Protocol
            LocalPort   = $Port
            Action      = $Action
            Enabled     = "True"
        }
        
        # Agregar perfil si no es "Any"
        if ($Profile -ne "Any") {
            $ruleParams.Profile = $Profile
        }
        
        $rule = New-NetFirewallRule @ruleParams -ErrorAction Stop
        
        if ($rule) {
            Write-Host "`n" + ("=" * 60) -ForegroundColor Green
            Write-Host "✓ Regla de firewall creada exitosamente" -ForegroundColor Green
            Write-Host ("=" * 60) -ForegroundColor Green
            Write-Host ""
            
            # Mostrar información de la regla creada
            Write-Host "Detalles de la regla:" -ForegroundColor Cyan
            $rule | Select-Object Name, DisplayName, Enabled, Direction, Action, Protocol | Format-List
            
            Write-Host "Para ver la regla en el Firewall de Windows:" -ForegroundColor Yellow
            Write-Host "  1. Abre 'Windows Defender Firewall con seguridad avanzada'" -ForegroundColor White
            Write-Host "  2. Ve a 'Reglas de entrada' (Inbound) o 'Reglas de salida' (Outbound)" -ForegroundColor White
            Write-Host "  3. Busca: $DisplayName" -ForegroundColor White
            Write-Host ""
            
            return $true
        }
        
    } catch {
        Write-Host "`n" + ("=" * 60) -ForegroundColor Red
        Write-Host "✗ Error al crear la regla de firewall" -ForegroundColor Red
        Write-Host ("=" * 60) -ForegroundColor Red
        Write-Error "Error: $_"
        return $false
    }
}