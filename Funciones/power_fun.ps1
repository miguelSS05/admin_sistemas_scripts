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
    $aux= Get-NetIPAddress -InterfaceAlias "red_sistemas" -AddressFamily "IPv4" | Select-Object IPAddress | findstr "^[0-9]"

    if (!($aux -match '^(((10[0-9]|1?[1-9]?[0-9])|(2[0-4][0-9]|25[0-5]))\.){3}(((10[0-9]|1?[1-9]?[0-9])|(2[0-4][0-9]|25[0-5])))$')) {
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

	while (!($aux -match '^(((10[0-9]|1?[1-9]?[0-9])|(2[0-4][0-9]|25[0-5]))\.){3}(((10[0-9]|1?[1-9]?[0-9])|(2[0-4][0-9]|25[0-5])))$')) {
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
    } elseif (([int]$octets[0] -eq 169) -AND ([int]$octets[1] -eq 254)) {
        Write-Host "`nLos primeros octetos no pueden ser 169.254" -Foreground Red
        return $true;
    } elseif ([int]$octets[0] -ge 224) { # Banear clase D y E inválidas
        Write-Host "`nSe ha detectado que el primer octeto no pertenece a las clases A/B/C" -Foreground Red
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

    $octets[3] = $octets[3] + 1

    $octets[0]=[int]$octets[0]
    $octets[1]=[int]$octets[1]
    $octets[2]=[int]$octets[2]
    $octets[3]=[int]$octets[3]

    if ($octets[3] -ge 256) {
        $octets[2] = $octets[2]+1        
        $octets[3] = 0
    }

    if ($octets[2] -ge 256) {
        $octets[1] = $octets[1]+1        
        $octets[2] = 0
    }

    if ($octets[1] -ge 256) {
        $octets[0] = $octets[0]+1        
        $octets[1] = 0
    }

    return $octets[0]+"."+$octets[1]+"."+$octets[2]+"."+$octets[3]

}

function restartIp {
    param (
        [string]$ip
    )

    Remove-NetIPAddress -InterfaceIndex 2 -Confirm:$false
    New-NetIPAddress -InterfaceIndex 2 -IPAddress $ip
}