param (
    [string] $option,
    [switch] $install,
    [switch] $help,
    [string] $domain,
    [string] $ttl,
    [string] $configureIp,
    [string] $ip
)

. ../Funciones/power_fun_par.ps1

$helpM="--- Opciones ---`n`n"
$helpM="${helpM}1) Verificar existencia del servicio`n"
$helpM="${helpM}2) Instalar servicio`n"
$helpM="${helpM}3) Monitoreo`n" # Verificar sintaxis y ver estado del servicio
$helpM="${helpM}4) Agregar zona`n"
$helpM="${helpM}5) Eliminar zona`n"
$helpM="${helpM}6) Consultar lista de zonas (dominios)`n"
$helpM="${helpM}7) Verificar configuración IP`n"
$helpM="${helpM}--- Banderas ---`n`n"
$helpM="${helpM}-help (mostrar este mensaje)`n"
$helpM="${helpM}-option (seleccionar opcion)`n"
$helpM="${helpM}-install (confirmar instalacion)`n"
$helpM="${helpM}-domain (nombre de dominio)`n" # Verificar sintaxis y ver estado del servicio
$helpM="${helpM}-ttl (time to live)`n"
$helpM="${helpM}-configureIp (colocar nueva IP a configurar)`n"
$helpM="${helpM}-ip (colocar IP del dominio)`n"

if ($help) {
    Write-Host $helpM
    exit 1
}

$color="yellow"
$ipLocal=""

function changeConf {
    $ipLocal = getLocalIp

    if ($ipLocal -eq "0") {
        Write-Host "Se ha detectado una configuracion de IP invalida" -ForegroundColor red
        exit 1
    }

	$aux = Get-Service -Name "DNS Server" -ErrorAction SilentlyContinue

	if ($aux -eq $null) {
		Write-Host "Se ha detectado que no se tiene instalado el DNS Server" -Foregroundcolor "red"
        exit 1
	} 

    validateEmpty "$domain" "Nombre de dominio"
    usableIp "$ip" "IP del dominio" $false
    validateTimeFormat "$ttl" "TimeToLive"

    $prefix= getLocalPrefix
    $netmask= getNetmask $ip
    $segment= getSegment $ip
    #$reverseSeg= getBackwardsSegment $netmask $ip

    $aux = Get-DnsServerZone -ZoneName "$domain" -ErrorAction SilentlyContinue

    if ($aux -ne $null) {
        Write-Host "Se ha detectado que existe una zona con ese nombre" -ForegroundColor red
        exit 1
    }

    Add-DnsServerPrimaryZone -Name "$domain" -ZoneFile "$domain.dns" -Confirm:$false
    Add-DnsServerResourceRecordA -Name "www" -ZoneName "$domain" -IPv4Address "$ip" -TimeToLive "$ttl" -Confirm:$false # Apuntar hacia www.dominio
    Add-DnsServerResourceRecordA -Name "@" -ZoneName "$domain" -IPv4Address "$ip" -TimeToLive "$ttl" -Confirm:$false # Apuntar hacia el dominio raiz

    $aux = Get-DnsServerZone -ZoneName "$domain" -ErrorAction SilentlyContinue

    if ($aux -eq $null) {
        Write-Host "Se ha creado la zona $domain correctamente" -ForegroundColor green
        exit 1
    }
    #Add-DnsServerPrimaryZone -NetworkId "$segment/$prefix" -ZoneFile "$domain.dns" # Crear zona de busqueda inversa
}

function checkService {
	$aux = Get-Service -Name "DNS Server" -ErrorAction SilentlyContinue

	if ($aux -eq $null) {
		Write-Host "Se ha detectado que no se tiene instalado el DNS Server" -Foregroundcolor "red"

	} else {
        Write-Host "Se ha detectado el servicio DNS instalado" -Foreground $color
    } 
}

function readZones {
	$aux = Get-Service -Name "DNS Server" -ErrorAction SilentlyContinue

	if ($aux -eq $null) {
		Write-Host "Se ha detectado que no se tiene instalado el DNS Server" -Foregroundcolor "red"

	} else {
        Write-Host "`n=== Zonas (dominios) registrados ===" -ForegroundColor $color
        Get-DnsServerZone
    } 
}

function checkService {
	$aux = Get-Service -Name "DNS Server" -ErrorAction SilentlyContinue

	if ($aux -eq $null) {
		Write-Host "Se ha detectado que no se tiene instalado el DNS Server" -Foregroundcolor "red"

	} else {
        Write-Host "Se ha detectado el servicio DNS instalado" -Foreground $color
    } 
}

function monitoreo {
	$aux = Get-Service -Name "DNS Server" -ErrorAction SilentlyContinue

	if ($aux -eq $null) {
		Write-Host "Se ha detectado que no se tiene instalado el DNS Server" -Foregroundcolor "red"
	} else {
        Write-Host "`n=== Estado del servicio ===" -ForegroundColor $color
        Get-Service -Name "DNS Server" -ErrorAction SilentlyContinue | ft -Autosize
    } 
}

function deleteZone {
    validateEmpty "$domain" "Nombre de dominio" # Validar que no este vacio
    $aux = Get-DnsServerZone -ZoneName "$domain" -ErrorAction SilentlyContinue

    if ($aux -eq $null) {
        Write-Host "No se ha detectado una zona con ese nombre" -ForegroundColor red
        exit 1
    }

    Remove-DnsServerZone -ZoneName "$domain" -Confirm:$false

    $aux = Get-DnsServerZone -ZoneName "$domain" -ErrorAction SilentlyContinue

    if ($aux -eq $null) {
        Write-Host "Se ha eliminado la zona $domain correctamente" -ForegroundColor green
        exit 1
    }
}

function configureIp {
    $ipLocal = getLocalIp

    if ($ipLocal -eq "0") {
        Write-Host "Se ha detectado una configuracion de IP invalida" -ForegroundColor red
    } else {
        Write-Host "Se ha detectado una configuracion de IP valida" -ForegroundColor green
        exit 1
    }

    usableIP $configureIp "Nueva IP" $false
    restartIp $configureIp
}

function installService {
	$aux = Get-Service -Name "DNS Server" -ErrorAction SilentlyContinue

	if ($aux -eq $null) {
        Write-Host "Se ha detectado que no se tiene instalado el DHCP Server" -Foregroundcolor "red"

        if ($install) {
            Write-Host "Iniciando instalacion..." -Foregroundcolor $color
		    Install-WindowsFeature DNS -IncludeManagementTools	
		    Write-Host "La instalacion ha finalizado correctamente" -Foregroundcolor "green"   
        } else {
            Write-Host "Use la bandera -install para activar la instalacion" -ForegroundColor $color
        }

	} else {
        Write-Host "Se ha detectado el servicio DHCP instalado" -Foreground $color
    } 
}

switch ($option) {
    "1" {checkService; break;}
	"2" {installService; break;}
	"3" {monitoreo; break;}
	"4" {changeConf; break;}
    "5" {deleteZone; break;}
    "6" {readZones break;}
    "7" {configureIp break;}
	default {Write-Host "Se ha detectado una opcion invalida, vuelve a intentarlo" -Foregroundcolor red}
}