param (
    [string] $option,
    [switch] $install,
    [switch] $confirm,
    [switch] $help,
    [string] $leasetime,
    [string] $ttl,
    [string] $domain,
    [string] $ip1,
    [string] $ip2,
    [string] $dns1,
    [string] $dns2,
    [string] $gateway,
    [string] $scope
)

. ../Funciones/power_fun_par.ps1

$helpM="--- Opciones ---`n`n"
$helpM="${helpM}--- Script SSH ---`n`n"
$helpM="${helpM}1) Verificar existencia del servicio SSH`n"
$helpM="${helpM}2) Instalar servicio SSH`n`n"
$helpM="${helpM}--- Script Instalacion SO ---`n`n"
$helpM="${helpM}3) Verificar estatus del sistema`n`n" # Verificar sintaxis y ver estado del servicio
$helpM="${helpM}--- Script Gestion DHCP ---`n`n"
$helpM="${helpM}4) Verificar existencia del servicio DHCP`n"
$helpM="${helpM}5) Instalar servicio DHCP`n"
$helpM="${helpM}6) Configurar servicio DHCP`n"
$helpM="${helpM}7) Monitoreo servicio DHCP`n`n"
$helpM="${helpM}--- Script Gestion DNS ---`n`n"
$helpM="${helpM}8) Verificar existencia del servicio DNS`n"
$helpM="${helpM}9) Instalar el servicio DNS`n"
$helpM="${helpM}10) Monitoreo servicio DNS`n"
$helpM="${helpM}11) Agregar zona DNS`n"
$helpM="${helpM}12) Eliminar zona DNS`n"
$helpM="${helpM}13) Consultar lista de zonas DNS`n"
$helpM="${helpM}--- Banderas---`n`n"
$helpM="${helpM}-help (mostrar este mensaje)`n"
$helpM="${helpM}-option (seleccionar opcion)`n"
$helpM="${helpM}-install (confirmar instalacion)`n"
$helpM="${helpM}-domain (nombre de dominio)`n" # Verificar sintaxis y ver estado del servicio
$helpM="${helpM}-ttl (time to live)`n"
$helpM="${helpM}-scope (ambito)`n"
$helpM="${helpM}-leasetiempo (Tiempo de concesiones)`n"
$helpM="${helpM}-ip1 (colocar IP del dominio | colocar IP inicial del rango DHCP)`n"
$helpM="${helpM}-ip2 (colocar IP final del rango DHCP)`n"
$helpM="${helpM}-dns1 (colocar DNS primaria DHCP)`n"
$helpM="${helpM}-dns2 (colocar DNS secundaria DHCP)`n"
$helpM="${helpM}-gateway (colocar puerta de enlace DHCP)`n"

if ($help) {
    Write-Host $helpM
    exit 1
}

switch ($option) {
    "1" {
        $resul = Get-WindowsCapability -Online | Where-Object {$_.Name -like "OpenSSH.Server*" -AND $_.State -eq "NotPresent"}

        if ($resul -ne $null) {
            Write-Host "No se ha instalado el servicio OpenSSH.Server" -ForegroundColor "red"
        } else {
            Write-Host "Se ha detectado el servicio OpenSSH.Server" -ForegroundColor "green"
        }
        break;}
	"2" { 
        $resul = Get-WindowsCapability -Online | Where-Object {$_.Name -like "OpenSSH.Server*" -AND $_.State -eq "NotPresent"}

        if ($resul -ne $null) {
            if (!$install) {
                Write-Host "Utilice la bandera -install para confirmar instalacion" -Foregroundcolor "yellow"
                exit 1
            }

            Get-WindowsCapability -Online | Where-Object {$_.Name -like "OpenSSH.Server*" -AND $_.State -eq "NotPresent"} | Add-WindowsCapability -Online
            $resul = Get-WindowsCapability -Online | Where-Object {$_.Name -like "OpenSSH.Server*" -AND $_.State -eq "Installed"}

            if ($resul -ne $null) {
                $resul = Get-NetFirewallRule | Where-Object {$_.Name -eq "EnableSSH"}

                if ($resul -eq $null) {
                    New-NetFirewallRule -Name "EnableSSH" -DisplayName "EnableSSH" -Protocol TCP -LocalPort 22 -Action Allow -RemoteAddress Any
                }

                Write-Host "Se ha instalado correctamente el servicio OpenSSH.Server"
                Write-Host "Reiniciando servicio"
                Restart-Service -Name "sshd"
            }
        } else {
            Write-Host "Se ha detectado el servicio OpenSSH.Server" -ForegroundColor "green"
        }        
        break;}
	"3" {../Tarea_1/check_status.ps1; break;}
	"4" {../Tarea_2/gestion_dhcp_par.ps1 -o 1; break;}
    "5" {
        if ($install) {
            ../Tarea_2/gestion_dhcp_par.ps1 -o 2 -install;
        } else {
            ../Tarea_2/gestion_dhcp_par.ps1 -o 2;
        }
        break; 
        }
    "6" {
        if ($confirm) {
            ../Tarea_2/gestion_dhcp_par.ps1 -o 3 -confirm -scope $scope -ip1 $ip1 -ip2 $ip2 -dns1 $dns1 -dns2 $dns2 -gateway $gateway -leasetime $leasetime
        } else {
            ../Tarea_2/gestion_dhcp_par.ps1 -o 3 -scope $scope -ip1 $ip1 -ip2 $ip2 -dns1 $dns1 -dns2 $dns2 -gateway $gateway -leasetime $leasetime
        }
        break;}
    "7" {../Tarea_2/gestion_dhcp_par.ps1 -o 4; break;}
    "8" {../Tarea_3/gestion_dns.ps1 -o 1 break;}
    "9" {
        if ($install) {
            ../Tarea_3/gestion_dns.ps1 -o 2 -install
        } else {
            ../Tarea_3/gestion_dns.ps1 -o 2
        } 
        break;}
    "10" {../Tarea_3/gestion_dns.ps1 -o 3; break;}
    "11" {../Tarea_3/gestion_dns.ps1 -o 4 -ip $ip1 -domain $domain -ttl $ttl; break;}
    "12" {../Tarea_3/gestion_dns.ps1 -o 5 -domain $domain; break;}
    "13" {../Tarea_3/gestion_dns.ps1 -o 6 ; break;}

	default {Write-Host "Se ha detectado una opcion invalida, vuelve a intentarlo" -Foregroundcolor red}
}