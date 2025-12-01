# Script de Verificacion de Configuracion Flutter Windows
# Ejecuta este script para verificar tu entorno de desarrollo

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  Verificacion de Configuracion  " -ForegroundColor Cyan
Write-Host "  Flutter Windows Development    " -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Verificar Flutter
Write-Host "[1/5] Verificando Flutter..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version 2>&1 | Select-String "Flutter"
    if ($flutterVersion) {
        Write-Host "  OK Flutter instalado" -ForegroundColor Green
        Write-Host "    $flutterVersion" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  X Flutter no encontrado" -ForegroundColor Red
    Write-Host "    Instala Flutter desde: https://flutter.dev" -ForegroundColor Red
}

Write-Host ""

# Verificar Dart
Write-Host "[2/5] Verificando Dart..." -ForegroundColor Yellow
try {
    $dartVersion = dart --version 2>&1
    if ($dartVersion) {
        Write-Host "  OK Dart instalado" -ForegroundColor Green
        Write-Host "    $dartVersion" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  X Dart no encontrado" -ForegroundColor Red
}

Write-Host ""

# Verificar Visual Studio
Write-Host "[3/5] Verificando Visual Studio..." -ForegroundColor Yellow
$vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vsWhere) {
    $vsInstallation = & $vsWhere -latest -property installationPath
    if ($vsInstallation) {
        Write-Host "  OK Visual Studio encontrado" -ForegroundColor Green
        Write-Host "    Ruta: $vsInstallation" -ForegroundColor Gray
        
        # Verificar C++ workload
        $vcTools = Join-Path $vsInstallation "VC\Tools\MSVC"
        if (Test-Path $vcTools) {
            Write-Host "  OK Herramientas de C++ instaladas" -ForegroundColor Green
        }
        else {
            Write-Host "  X Herramientas de C++ NO encontradas" -ForegroundColor Red
            Write-Host "    Instala 'Desktop development with C++' desde Visual Studio Installer" -ForegroundColor Red
        }
    }
}
else {
    Write-Host "  X Visual Studio NO instalado" -ForegroundColor Red
    Write-Host "    Descarga desde: https://visualstudio.microsoft.com/downloads/" -ForegroundColor Red
    Write-Host "    Selecciona 'Desktop development with C++' durante la instalacion" -ForegroundColor Red
}

Write-Host ""

# Verificar dependencias del proyecto
Write-Host "[4/5] Verificando dependencias del proyecto..." -ForegroundColor Yellow
$pubspecLock = "pubspec.lock"
if (Test-Path $pubspecLock) {
    Write-Host "  OK Dependencias instaladas (pubspec.lock existe)" -ForegroundColor Green
}
else {
    Write-Host "  ! Dependencias no instaladas" -ForegroundColor Yellow
    Write-Host "    Ejecuta: flutter pub get" -ForegroundColor Yellow
}

Write-Host ""

# Ejecutar Flutter Doctor
Write-Host "[5/5] Ejecutando Flutter Doctor..." -ForegroundColor Yellow
Write-Host ""
flutter doctor -v

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  Verificacion Completada        " -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Resumen
Write-Host "PROXIMOS PASOS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Si Visual Studio NO esta instalado:" -ForegroundColor White
Write-Host "   - Descarga Visual Studio Community 2022" -ForegroundColor Gray
Write-Host "   - Selecciona 'Desktop development with C++'" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Si las dependencias NO estan instaladas:" -ForegroundColor White
Write-Host "   - Ejecuta: flutter pub get" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Para ejecutar la aplicacion:" -ForegroundColor White
Write-Host "   - Ejecuta: flutter run -d windows" -ForegroundColor Gray
Write-Host ""

# Preguntar si quiere instalar dependencias
if (-not (Test-Path $pubspecLock)) {
    $response = Read-Host "Deseas instalar las dependencias ahora? (s/n)"
    if (($response -eq "s") -or ($response -eq "S")) {
        Write-Host ""
        Write-Host "Instalando dependencias..." -ForegroundColor Yellow
        flutter pub get
    }
}
