# Script de Ayuda para Instalacion de Visual Studio
# Este script te guiara a traves del proceso

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Instalacion de Visual Studio 2022    " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "PASO 1: DESCARGAR" -ForegroundColor Yellow
Write-Host "----------------" -ForegroundColor Yellow
Write-Host "1. Se ha abierto la pagina de descarga en tu navegador" -ForegroundColor White
Write-Host "2. Busca 'Visual Studio Community 2022'" -ForegroundColor White
Write-Host "3. Haz clic en 'Free download' bajo Community" -ForegroundColor White
Write-Host "4. Se descargara 'VisualStudioSetup.exe' (~3 MB)" -ForegroundColor White
Write-Host ""

$response = Read-Host "Presiona ENTER cuando hayas descargado el instalador"

Write-Host ""
Write-Host "PASO 2: EJECUTAR INSTALADOR" -ForegroundColor Yellow
Write-Host "----------------------------" -ForegroundColor Yellow
Write-Host "1. Ve a tu carpeta de Descargas" -ForegroundColor White
Write-Host "2. Ejecuta 'VisualStudioSetup.exe'" -ForegroundColor White
Write-Host "3. Si Windows pregunta, haz clic en 'Si' para permitir cambios" -ForegroundColor White
Write-Host "4. Espera a que el instalador se inicie" -ForegroundColor White
Write-Host ""

$response = Read-Host "Presiona ENTER cuando el instalador este abierto"

Write-Host ""
Write-Host "PASO 3: SELECCIONAR WORKLOAD (MUY IMPORTANTE)" -ForegroundColor Yellow
Write-Host "----------------------------------------------" -ForegroundColor Yellow
Write-Host ""
Write-Host "  *** ATENCION: Este es el paso MAS IMPORTANTE ***" -ForegroundColor Red
Write-Host ""
Write-Host "En la ventana del instalador:" -ForegroundColor White
Write-Host "1. Busca la pestana 'Workloads' (Cargas de trabajo)" -ForegroundColor White
Write-Host "2. MARCA LA CASILLA de:" -ForegroundColor White
Write-Host ""
Write-Host "   [X] Desktop development with C++" -ForegroundColor Green
Write-Host "   (o en espanol: Desarrollo para el escritorio con C++)" -ForegroundColor Green
Write-Host ""
Write-Host "3. NO necesitas seleccionar nada mas" -ForegroundColor White
Write-Host "4. Haz clic en 'Install' (Instalar) en la esquina inferior derecha" -ForegroundColor White
Write-Host ""

$response = Read-Host "Presiona ENTER cuando hayas iniciado la instalacion"

Write-Host ""
Write-Host "PASO 4: ESPERAR INSTALACION" -ForegroundColor Yellow
Write-Host "----------------------------" -ForegroundColor Yellow
Write-Host "La instalacion tomara entre 30-60 minutos" -ForegroundColor White
Write-Host "Puedes dejar esto corriendo en segundo plano" -ForegroundColor White
Write-Host ""
Write-Host "Descarga: ~6-8 GB" -ForegroundColor Gray
Write-Host "Espacio necesario: ~15-20 GB" -ForegroundColor Gray
Write-Host ""

$response = Read-Host "Presiona ENTER cuando la instalacion haya TERMINADO"

Write-Host ""
Write-Host "PASO 5: VERIFICAR INSTALACION" -ForegroundColor Yellow
Write-Host "------------------------------" -ForegroundColor Yellow
Write-Host "Verificando que Visual Studio se instalo correctamente..." -ForegroundColor White
Write-Host ""

# Verificar Visual Studio
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vsWhere) {
    $vsInstallation = & $vsWhere -latest -property installationPath
    if ($vsInstallation) {
        Write-Host "  OK Visual Studio encontrado!" -ForegroundColor Green
        Write-Host "     Ruta: $vsInstallation" -ForegroundColor Gray
        
        # Verificar C++ workload
        $vcTools = Join-Path $vsInstallation "VC\Tools\MSVC"
        if (Test-Path $vcTools) {
            Write-Host "  OK Herramientas de C++ instaladas!" -ForegroundColor Green
        }
        else {
            Write-Host "  X Herramientas de C++ NO encontradas" -ForegroundColor Red
            Write-Host "     Parece que olvidaste seleccionar 'Desktop development with C++'" -ForegroundColor Red
            Write-Host "     Abre Visual Studio Installer y haz clic en 'Modify' para agregar el workload" -ForegroundColor Yellow
        }
    }
}
else {
    Write-Host "  X Visual Studio NO detectado" -ForegroundColor Red
    Write-Host "     Asegurate de que la instalacion haya terminado completamente" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Ejecutando Flutter Doctor..." -ForegroundColor White
Write-Host ""
flutter doctor -v

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Instalacion Completada                " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar si todo esta listo
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vsWhere) {
    $vsInstallation = & $vsWhere -latest -property installationPath
    if ($vsInstallation) {
        $vcTools = Join-Path $vsInstallation "VC\Tools\MSVC"
        if (Test-Path $vcTools) {
            Write-Host "EXITO! Todo esta listo para desarrollar en Flutter Windows" -ForegroundColor Green
            Write-Host ""
            Write-Host "Ahora puedes ejecutar tu aplicacion con:" -ForegroundColor White
            Write-Host "  flutter run -d windows" -ForegroundColor Cyan
            Write-Host ""
            
            $runNow = Read-Host "Deseas ejecutar la aplicacion ahora? (s/n)"
            if (($runNow -eq "s") -or ($runNow -eq "S")) {
                Write-Host ""
                Write-Host "Ejecutando aplicacion..." -ForegroundColor Yellow
                flutter run -d windows
            }
        }
    }
}
else {
    Write-Host "Parece que hay un problema con la instalacion." -ForegroundColor Yellow
    Write-Host "Por favor, revisa los pasos anteriores." -ForegroundColor Yellow
}
