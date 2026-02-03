Write-Host "=== Script Bienvenida ==="

# Escribir nombre del equipo
Write-Host "Nombre del equipo: " -NoNewLine
$env:COMPUTERNAME

# Mostrar IP Interna de la interfaz red_sistemas
Write-Host "IP Interna del equipo: " -NoNewLine
Get-NetIPAddress -InterfaceAlias "red_sistemas" -AddressFamily "IPv4" | Select-Object IPAddress | findstr "^[0-9]"

# Obtener el espacio en memoria
Get-PSDrive C | Select-Object Used,Free | ForEach-Object {$used = [Math]::round($_.Used / 1GB, 2); $free = [Math]::round($_.Free / 1GB,2); }

Write-Host "Espacio usado disco: ", $used, "GB"
Write-Host "Espacio libre disco: ", $free, "GB"
