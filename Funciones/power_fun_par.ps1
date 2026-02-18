function validateEmpty {
	param (
		[string]$value,
        [string]$var
	)

	$value = $value.trim()

    if ($value -eq "") {
        Write-Host "`nSe ha detectado un espacio vacio, saliendo del programa (variable: '$var')" -Foreground Red
        exit 1
    } else {
        Write-Host "`nNo se ha detectado vacio"
    }
}

function validateIp {
	param (
		[string]$ip,
        [string]$var,
        [boolean]$opt
	)

    #if ((($ip -eq "N") -or ($ip -eq "n")) -and ($opt -eq $true)) {return $aux}

    if (!($ip -match '^\s*(((10[0-9]|1?[1-9]?[0-9])|(2[0-4][0-9]|25[0-5]))\.){3}(((10[0-9]|1?[1-9]?[0-9])|(2[0-4][0-9]|25[0-5])))\s*$')) {
        Write-Host "`nNo se ha detectado el formato IPv4, saliendo del programa (variable: '$var')" -Foreground Red
        exit 1
    }
}

function validateInt {
	param (
		[string]$num1,
        [string]$var,
        [boolean]$opt
	)

    #if ((($num1 -eq "N") -or ($num1 -eq "n")) -and ($opt -eq $true)) {return $num1}

    if (!($num1 -match '^\d+$')) {
        Write-Host "`nNo se ha detectado un numero entero sin signos, saliendo del programa (variable: '$var')" -Foreground Red
        exit 1
    }
}

function banIp {
	param (
		[string]$ip,
        [string]$var
	)

    $octets = $ip -split "\."

    if ([int]$octets[0] -eq 0) {
        Write-Host "`nEl primer octeto no puede ser 0, saliendo del programa (variable: '$var')" -Foreground Red
        exit 1
    } elseif ([int]$octets[0] -eq 127) {
        Write-Host "`nEl primer octeto no puede ser 127, saliendo del programa (variable: '$var')" -Foreground Red
        exit 1
    } elseif ([int]$octets[0] -eq 255) { # Banear clase D y E inv�lidas
        Write-Host "`nEl primer octeto no puede ser 255, saliendo del programa (variable: '$var')" -Foreground Red
        exit 1
    }
}

function usableIp {
	param (
		[string]$ip,
        [string]$var,
        [boolean]$opt
	)

    validateIp $ip $var $opt
    banIp $ip $var
}

function getLocalPrefix {
	$aux = Get-NetIPAddress -InterfaceIndex 2 | Select-Object PrefixLength | findstr '[0-9]'
    $aux = $aux.Trim()
    return $aux
}

function getNetmask {
	param (
		[string]$ip
	)

    $octets = $ip -split "\."

    $octet1 = [int]$octets[0]

    if (($octet1 -ge 1) -AND ($octet1 -le 126)) {
        return "255.0.0.0"
    } elseif (($octet1 -ge 128) -AND ($octet1 -le 191)) {
        return "255.255.0.0"
    } elseif (($octet1 -ge 192) -AND ($octet1 -le 223)) {
        return "255.255.255.0"
    } else {
        # Nada
    }
}

function getBackwardsSegment {
	param (
		[string]$netmask,
        [string]$ip
	)

    $octets = $ip -split "\."

    if ($netmask -eq "255.255.255.0") {
        return $octets[0]+"."+$octets[1]+"."+$octets[2]+"."
    } elseif ($netmask -eq "255.255.0.0") {
        return $octets[0]+"."+$octets[1]+"."
    } elseif ($netmask -eq "255.0.0.0") {
        return $octets[0]+"."
    } else {
        Write-Host "Se ha detectado una mascara invalida" -ForegroundColor Red
        exit 1
    }
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

function getLocalIp {
    $aux = Get-NetIPAddress -InterfaceAlias "red_sistemas" -AddressFamily "IPv4" -ErrorAction SilentlyContinue | Select-Object IPAddress | findstr "^[0-9]"

    if (!($aux -match '^\s*(((10[0-9])|(1?[1-9]?[0-9])|(2[0-4][0-9])|(25[0-5]))\.){3}((10[0-9])|(1?[1-9]?[0-9])|(2[0-4][0-9])|(25[0-5]))\s*$')) {
		Write-Host "`nNo se ha detectado una IPv4 local valida" -Foreground Red
		return "0"
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

function validateTimeFormat {
	param (
		[string]$text
	)

	$aux = getText $text

	if (!($aux -match '^(\d+\.)?([0-1]?[0-9]|2[0-3]):[0-5]?[0-9](:[0-5]?[0-9])?$')) {
		Write-Host "`nNo se ha detectado un tiempo correto, formatos validos: (D.)?HH:MM:SS | (D.)?H:M:S | (D.)?HH:MM | (D.)?H:M" -Foreground Red
		exit 1
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