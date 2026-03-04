function validateEmpty {
	param (
		[string]$value,
        [string]$var
	)

	$value = $value.trim()

    if ($value -eq "") {
        Write-Host "`nSe ha detectado un espacio vacio, saliendo del programa (variable: '$var')" -Foreground Red
        exit 1
    }
}

function validateIp {
	param (
		[string]$ip,
        [string]$var,
        [boolean]$opt
	)

    if (($ip -eq "") -and ($opt -eq $true)) {return $aux}

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

    if (($ip -eq "") -AND ($opt)) { return $ip; }

    validateIp "$ip" "$var" $opt
    banIp "$ip" "$var"
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
		[string]$var,
        [string]$text
	)

	$var = $var.Trim()

	if (!($var -match '^(\d+\.)?([0-1]?[0-9]|2[0-3]):[0-5]?[0-9](:[0-5]?[0-9])?$')) {
		Write-Host "`nNo se ha detectado un tiempo correto, formatos validos: (D.)?HH:MM:SS | (D.)?H:M:S | (D.)?HH:MM | (D.)?H:M (variable: $text)" -Foreground Red
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

function verificarAdmin {
    $resul = whoami
    $resul = $resul -split "\"

    if ($resul[1] -ne "administrator") {
        Write-Host "Se ha detectado que no se ha iniciado con la cuenta administrator" -Foregroundcolor "red"
        exit 1
    }
}

function validateEmptyArray {
    param (
        [array] $array
    )

    foreach($element in $array) {
        if ($element -eq $null) {
            Write-Host "Se ha detectado un valor vacio en el arreglo" -Foreground red
            exit 1
        }
    }
}

function validateGroupNumber {
    param (
        [array] $array
    )

    foreach($element in $array) {
        if (($element -ne "1") -AND ($element -ne "2")) {
            Write-Host "Se ha detectado un grupo que no es ni 1 ni 2" -Foreground red
            exit 1
        }
    }
}

function validateUserCreated {
    param (
        [array] $array
    )

    foreach($element in $array) {
        $aux = Get-LocalUser -Name $element -ErrorAction SilentlyContinue

        if ($aux -ne $null) {
            Write-Host "Se ha encontrado que el usuario '$aux' ya ha sido creado"
            exit 1
        }
    }
}
