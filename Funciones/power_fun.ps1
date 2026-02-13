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

    if (($aux -eq $null)) {
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

function restartIp {
    param (
        [string]$ip
    )

    Remove-NetIPAddress -InterfaceIndex 2 -Confirm:$false
    New-NetIPAddress -InterfaceIndex 2 -IPAddress $ip -Confirm:$false > $null 2>&1
}

function GetNetmaskCIDR {
    param (
        [int]$val1,   
        [int]$val2,   
        [int]$ip1, 
        [int]$ip2
    )

    $octets1 = $v[$ip1] -split "\."
    $octets2 = $v[$ip2] -split "\."

    $octet11 = [int]$octets1[0]
    $octet21 = [int]$octets1[1]
    $octet31 = [int]$octets1[2]
    $octet41 = [int]$octets1[3]

    $octet12 = [int]$octets2[0]
    $octet22 = [int]$octets2[1]
    $octet32 = [int]$octets2[2]
    $octet42 = [int]$octets2[3]

    # Calcular la diferencia absoluta + 2
    if ($val1 -gt $val2) {
        $resul = $val1 - $val2
    } else {
        $resul = $val2 - $val1
    }
    $resul += 2

    # Calcular la cantidad de bits necesarios
    $count = 0
    $accum = 1
    while ($resul -ge $accum) {
        $count++
        $accum *= 2
    }

    $netw = 32 - $count
    $netseg_count = [math]::Floor($netw / 8)
    $block = $netw - $netseg_count * 8
    $block = 8 - $block
    $block = [math]::Pow(2, $block)

    $aux = 4 - $netseg_count

    switch ($aux) {
        1 { $pivot1 = $octet41; $pivot2 = $octet42; $multiplier = 0 }
        2 { $pivot1 = $octet31; $pivot2 = $octet32; $multiplier = 256 }
        3 { $pivot1 = $octet21; $pivot2 = $octet22; $multiplier = 256*256 }
        4 { $pivot1 = $octet11; $pivot2 = $octet12; $multiplier = 256*256*256 }
    }

    $div1 = [math]::Floor($pivot1 / $block)
    $div2 = [math]::Floor($pivot2 / $block)

    while ($div1 -ne $div2) {
        $netw--
        $netseg_count = [math]::Floor($netw / 8)
        $block = $netw - $netseg_count * 8
        $block = 8 - $block
        $block = [math]::Pow(2, $block)

        $div1 = [math]::Floor($pivot1 / $block)
        $div2 = [math]::Floor($pivot2 / $block)
    }

    $oct_count = 0
    $netmask = ""
    $netsegment = ""

    $tmpNetw = $netw
    while ($tmpNetw -ge 8) {
        $oct_count++
        $netmask += if ($oct_count -lt 4) { "255." } else { "255" }

        switch ($oct_count) {
            1 { $netsegment += "$octet11." }
            2 { $netsegment += "$octet21." }
            3 { $netsegment += "$octet31." }
            4 { $netsegment += "$octet41" }
        }

        $tmpNetw -= 8
    }

    # Octeto parcial restante
    if ($oct_count -ge 3) { 
        $oct_count++
        $netmask += switch ($tmpNetw) {
            7 { "254" }
            6 { "252" }
            5 { "248" }
            4 { "240" }
            3 { "224" }
            2 { "192" }
            1 { "128" }
            0 { $oct_count--; ""; break }
        }
        $netsegment += ($div1 * $block)
    } else {
        $oct_count++
        $netmask += switch ($tmpNetw) {
            7 { "254." }
            6 { "252." }
            5 { "248." }
            4 { "240." }
            3 { "224." }
            2 { "192." }
            1 { "128." }
            0 { $oct_count--; ""; break }
        }
        $netsegment += ($div1 * $block) + "."
    }

    # Completar los octetos faltantes
    while ($oct_count -lt 4) {
        $oct_count++
        if ($oct_count -eq 4) {
            $netmask += "0"
            $netsegment += "0"
        } else {
            $netmask += "0."
            $netsegment += "0."
        }
    }

    #$v[$netmaskIdx] = $netmask
    #$v[$netsegmentIdx] = $netsegment

    $summ = $multiplier * $block - 1

    $ipFinal = sumMany -ip $netsegment -sum $summ 

    return "$netmask|$netsegment|$ipFinal"
}

function sumMany {
    param (
        [int]$ip,   
        [int]$sum     
    )

    $octets = $ip -split "\."

    $octet1 = [int]$octets[0]
    $octet2 = [int]$octets[1]
    $octet3 = [int]$octets[2]
    $octet4 = [int]$octets[3]

    $octet4 += $sum

    if ($octet4 -ge 256) {
        $octet3 += [math]::Floor($octet4 / 256)
        $octet4 = $octet4 % 256
    }

    if ($octet3 -ge 256) {
        $octet2 += [math]::Floor($octet3 / 256)
        $octet3 = $octet3 % 256
    }

    if ($octet2 -ge 256) {
        $octet1 += [math]::Floor($octet2 / 256)
        $octet2 = $octet2 % 256
    }

    return "$octet1.$octet2.$octet3.$octet4"
}