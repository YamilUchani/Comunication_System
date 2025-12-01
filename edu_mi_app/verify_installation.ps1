# Script Automatico de Verificacion Post-Instalacion
# Ejecuta este script DESPUES de instalar Visual Studio

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Verificacion Post-Instalacion        " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar Visual Studio
Write-Host "Verificando Visual Studio..." -ForegroundColor Yellow
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

if (Test-Path $vsWhere) {
    $vsInstallation = & $vsWhere -latest -property installationPath
    if ($vsInstallation) {
        Write-Host "  OK Visual Studio encontrado" -ForegroundColor Green
        Write-Host "     Ruta: $vsInstallation" -ForegroundColor Gray
        
        $vcTools = Join-Path $vsInstallation "VC\Tools\MSVC"
        if (Test-Path $vcTools) {
            Write-Host "  OK Herramientas de C++ instaladas" -ForegroundColor Green
            $allGood = $true
        }
        else {
            Write-Host "  X Herramientas de C++ NO encontradas" -ForegroundColor Red
            Write-Host "     SOLUCION: Abre Visual Studio Installer y selecciona 'Modify'" -ForegroundColor Yellow
            Write-Host "     Luego marca 'Desktop development with C++' y haz clic en Modify" -ForegroundColor Yellow
            $allGood = $false
        }
    }
    else {
        Write-Host "  X Visual Studio no encontrado" -ForegroundColor Red
        $allGood = $false
    }
}
else {
    Write-Host "  X Visual Studio NO instalado" -ForegroundColor Red
    Write-Host "     Necesitas instalar Visual Studio Community 2022" -ForegroundColor Yellow
    Write-Host "     Descarga desde: https://visualstudio.microsoft.com/downloads/" -ForegroundColor Yellow
    $allGood = $false
}

Write-Host ""
Write-Host "Ejecutando Flutter Doctor..." -ForegroundColor Yellow
Write-Host ""
flutter doctor -v

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

if ($allGood) {
    Write-Host "  TODO LISTO!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Tu entorno de desarrollo esta completamente configurado." -ForegroundColor Green
    Write-Host ""
    Write-Host "Para ejecutar tu aplicacion:" -ForegroundColor White
    Write-Host "  flutter run -d windows" -ForegroundColor Cyan
    Write-Host ""
    
    $runNow = Read-Host "Deseas ejecutar la aplicacion ahora? (s/n)"
    if (($runNow -eq "s") -or ($runNow -eq "S")) {
        Write-Host ""
        Write-Host "Iniciando aplicacion..." -ForegroundColor Yellow
        Write-Host ""
        flutter run -d windows
    }
}
else {
    Write-Host "  ATENCION: Configuracion incompleta" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Por favor, completa la instalacion de Visual Studio" -ForegroundColor Yellow
    Write-Host "y asegurate de seleccionar 'Desktop development with C++'" -ForegroundColor Yellow
}
