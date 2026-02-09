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

function validateIp {
	param (
		[string]$text
	)

	$aux = getText $text

	while (!($aux -match '^(((10[0-9]|1?[1-9]?[0-9])|(2[0-4][0-9]|25[0-5]))\.){3}(((10[0-9]|1?[1-9]?[0-9])|(2[0-4][0-9]|25[0-5])))$')) {
		Write-Host "`nNo se ha detectado el formato IPv4, vuelva a intentarlo" -Foreground Red
		$aux = getText $text 
	}

	return $aux
}

function validateInt {
	param (
		[string]$text
	)

	$aux = getText $text

	while (!($aux -match '^\d+$')) {
		Write-Host "`nNo se ha detectado un numero sin signos (+ | -), vuelva a intentarlo" -Foreground Red
		$aux = getText $text 
	}

	return $aux
}

function validateTimeFormat {
	param (
		[string]$text
	)

	$aux = getText $text

	Write-host "El valor de aux es: $aux"

	while (!($aux -match '^(\d+\.)?([0-1]?[0-9]|2[0-3]):[0-5]?[0-9](:[0-5]?[0-9])?$')) {
		Write-Host "`nNo se ha detectado un tiempo correto, formatos válidos: (D.)?HH:MM:SS | (D.)?H:M:S | (D.)?HH:MM | (D.)?H:M" -Foreground Red
		$aux = getText $text 
	}

	return $aux
}
