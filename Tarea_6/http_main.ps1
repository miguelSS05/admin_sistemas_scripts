# Esto busca en la carpeta "Funciones" que está al mismo nivel que tu script
. "$PSScriptRoot\..\Funciones\power_fun.ps1"

# Esto busca en la misma carpeta donde está tu script
. "$PSScriptRoot\http_functions.ps1"

function Mostrar-MenuServidoresWeb {
    Clear-Host
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "       GESTOR DE SERVIDORES WEB (PS)" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "1) Menú Apache"
    Write-Host "2) Menú Nginx"
    Write-Host "3) Menú IIS"
    Write-Host "0) Salir"
    Write-Host "==============================================" -ForegroundColor Cyan
}

function Mostrar-MenuWebApache {
    Clear-Host
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "       SERVIDOR APACHE" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "1) Listar versiones de Apache"
    Write-Host "2) Instalar Apache"
    Write-Host "3) Verificar instalacion Apache"
    Write-Host "4) Monitoreo Apache"
    Write-Host "5) Modificar puerto Apache"
    Write-Host "0) Salir"
    Write-Host "==============================================" -ForegroundColor Cyan
}

function Mostrar-MenuWebNginx {
    Clear-Host
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "       SERVIDOR NGINX" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "1) Listar versiones de NGINX"
    Write-Host "2) Instalar NGINX"
    Write-Host "3) Verificar instalacion NGINX"
    Write-Host "4) Monitoreo NGINX"
    Write-Host "5) Modificar puerto NGINX"
    Write-Host "0) Salir"
    Write-Host "==============================================" -ForegroundColor Cyan
}

function Mostrar-MenuWebIIS {
    Clear-Host
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "       SERVIDOR IIS" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "1) Instalar IIS"
    Write-Host "2) Verificar instalacion IIS"
    Write-Host "3) Monitoreo IIS"
    Write-Host "4) Modificar puerto IIS"
    Write-Host "0) Salir"
    Write-Host "==============================================" -ForegroundColor Cyan
}

function Menu-WebApache {
  $opcion=""

  do {
      Mostrar-MenuWebApache
      $opcion = Read-Host "Seleccione una opción"

      switch ($opcion) {
          "1" {
              Get-ChocoPackageVersions -PackageName "apache-httpd" -ShowTable
          }
          "2" {
              if (GetServiceExists -nombre "apache-http") {
                Write-Host "Se ha detectado que el servicio ya existe"
                return 1
              }

              $version = Read-Host "Seleccione una version"
              Install-ChocoPackage -PackageName "apache-httpd" -Version $version
          }
          "3" {
              VerifyServiceInstalation -nombre "Apache"
          }
          "4" {
              GetServiceEstatus -nombre "Apache"
          }
          "5" {
              $puerto = Read-Host "Seleccione un puerto"
              Configure-ApacheService -DocumentRoot "C:\WebServers\Apache" -CreateFirewallRule -Port $puerto
          }
          "0" {
              Write-Host "Saliendo del programa..." -ForegroundColor Green
              Start-Sleep -Seconds 1
          }
          Default {
              Write-Host "Opción no válida, por favor intente de nuevo." -ForegroundColor Red
              Start-Sleep -Seconds 2
          }
      }

      if ($opcion -ne "0") {
          Read-Host "`nPresione Enter para volver al menú"
      }

  } until ($opcion -eq "0")
}

function Menu-WebNginx {
  $opcion=""

  do {
      Mostrar-MenuWebNginx
      $opcion = Read-Host "Seleccione una opción"

      switch ($opcion) {
          "1" {
              Get-ChocoPackageVersions -PackageName "nginx" -ShowTable
          }
          "2" {
              if (GetServiceExists -nombre "nginx") {
                Write-Host "Se ha detectado que el servicio ya existe"
                return 1
              }
              
              $version = Read-Host "Seleccione una version"
              Install-ChocoPackage -PackageName "nginx" -Version $version
          }
          "3" {
              VerifyServiceInstalation -nombre "nginx"
          }
          "4" {
              GetServiceEstatus -nombre "nginx"
          }
          "5" {
              $puerto = Read-Host "Seleccione un puerto"
              Setup-NginxService -Port $puerto # -DocumentRoot "C:\WebServers\Nginx" -CreateFirewallRule 
          }
          "0" {
              Write-Host "Saliendo del programa..." -ForegroundColor Green
              Start-Sleep -Seconds 1
          }
          Default {
              Write-Host "Opción no válida, por favor intente de nuevo." -ForegroundColor Red
              Start-Sleep -Seconds 2
          }
      }

      if ($opcion -ne "0") {
          Read-Host "`nPresione Enter para volver al menú"
      }

  } until ($opcion -eq "0")
}

function Menu-WebIIS {
  $opcion=""

  do {
      Mostrar-MenuWebIIS
      $opcion = Read-Host "Seleccione una opción"

      switch ($opcion) {
          "1" { 
              if (GetServiceExists -nombre "W3SVC") {
                Write-Host "Se ha detectado que el servicio ya existe"
                return 1
              }

              Install-IISServer -install -silent
          }
          "2" {
              VerifyServiceInstalation -nombre "W3SVC"
          }
          "3" {
              GetServiceEstatus -nombre "W3SVC"
          }
          "4" {
              $port = Read-Host "Seleccione un puerto"
              New-IISWebsite -name "ServicioWebIIS" -port $port
          }
          "0" {
              Write-Host "Saliendo del programa..." -ForegroundColor Green
              Start-Sleep -Seconds 1
          }
          Default {
              Write-Host "Opción no válida, por favor intente de nuevo." -ForegroundColor Red
              Start-Sleep -Seconds 2
          }
      }

      if ($opcion -ne "0") {
          Read-Host "`nPresione Enter para volver al menú"
      }

  } until ($opcion -eq "0")
}

$opcion=-1;

do {
    Mostrar-MenuServidoresWeb
    $opcion = Read-Host "Seleccione una opción"

    switch ($opcion) {
        "1" {
          Menu-WebApache
        }
        "2" {
          Menu-WebNginx
        }
        "3" {
          Menu-WebIIS
        }
        "0" {
            Write-Host "Saliendo del programa..." -ForegroundColor Green
            Start-Sleep -Seconds 1
        }
        Default {
            Write-Host "Opción no válida, por favor intente de nuevo." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }

    if ($opcion -ne "0") {
        Read-Host "`nPresione Enter para volver al menú"
    }

} until ($opcion -eq "0")