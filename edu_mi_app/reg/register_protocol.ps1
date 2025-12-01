# Script para registrar el protocolo stemforall automáticamente
# Este script detecta la ubicación del .exe y registra el protocolo en el registro de Windows

param(
    [string]$BuildType = "Release"  # Puede ser "Debug" o "Release"
)

# Obtener la ruta del script (carpeta reg)
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath

# Construir la ruta al ejecutable
$exePath = Join-Path $projectRoot "build\windows\x64\runner\$BuildType\edu_mi_app.exe"

# Verificar si el ejecutable existe
if (-not (Test-Path $exePath)) {
    Write-Host "❌ Error: No se encontró el ejecutable en: $exePath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Por favor, compila la aplicación primero:" -ForegroundColor Yellow
    Write-Host "  flutter build windows --release" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "O si quieres usar la versión Debug:" -ForegroundColor Yellow
    Write-Host "  .\reg\register_protocol.ps1 -BuildType Debug" -ForegroundColor Cyan
    exit 1
}

Write-Host "✓ Ejecutable encontrado: $exePath" -ForegroundColor Green

# Escapar las barras invertidas para el registro
$exePathEscaped = $exePath -replace '\\', '\\'

# Crear el contenido del archivo .reg temporal
$regContent = @"
Windows Registry Editor Version 5.00

[HKEY_CLASSES_ROOT\stemforall]
@="URL:StemForAll Protocol"
"URL Protocol"=""

[HKEY_CLASSES_ROOT\stemforall\shell]

[HKEY_CLASSES_ROOT\stemforall\shell\open]

[HKEY_CLASSES_ROOT\stemforall\shell\open\command]
@="`"$exePathEscaped`" `"%1`""
"@

# Guardar el contenido en un archivo temporal
$tempRegFile = Join-Path $env:TEMP "stemforall_register_temp.reg"
$regContent | Out-File -FilePath $tempRegFile -Encoding ASCII

Write-Host ""
Write-Host "Registrando el protocolo stemforall..." -ForegroundColor Cyan

# Ejecutar el archivo .reg
try {
    Start-Process "regedit.exe" -ArgumentList "/s `"$tempRegFile`"" -Verb RunAs -Wait
    Write-Host "✓ Protocolo registrado exitosamente" -ForegroundColor Green
    Write-Host ""
    Write-Host "Ahora puedes usar URLs como: stemforall://callback?access_token=..." -ForegroundColor Green
}
catch {
    Write-Host "❌ Error al registrar el protocolo: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Intenta ejecutar este script como administrador" -ForegroundColor Yellow
    exit 1
}
finally {
    # Limpiar el archivo temporal
    if (Test-Path $tempRegFile) {
        Remove-Item $tempRegFile -Force
    }
}

# Verificar el registro
Write-Host ""
Write-Host "Verificando el registro..." -ForegroundColor Cyan
$registeredPath = (Get-ItemProperty -Path "Registry::HKEY_CLASSES_ROOT\stemforall\shell\open\command" -Name "(default)")."(default)"
Write-Host "Ruta registrada: $registeredPath" -ForegroundColor Gray
