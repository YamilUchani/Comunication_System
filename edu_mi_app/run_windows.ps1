# Script para ejecutar la App en Windows
# Este script verifica si Flutter está instalado y ejecuta la aplicación.

Write-Host "🔍 Verificando instalación de Flutter..." -ForegroundColor Cyan

if (Get-Command flutter -ErrorAction SilentlyContinue) {
    Write-Host "✅ Flutter encontrado." -ForegroundColor Green
    
    Write-Host "📦 Instalando dependencias..." -ForegroundColor Cyan
    flutter pub get
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "🚀 Iniciando la aplicación en Windows..." -ForegroundColor Cyan
        flutter run -d windows
    } else {
        Write-Host "❌ Error al instalar dependencias." -ForegroundColor Red
        Write-Host "Intenta ejecutar 'flutter pub get' manualmente para ver el error." -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Flutter no encontrado." -ForegroundColor Red
    Write-Host "Por favor, asegúrate de haber instalado Flutter y agregado la carpeta 'bin' al PATH de tu sistema." -ForegroundColor Yellow
    Write-Host "Consulta el archivo installation_guide.md para más detalles." -ForegroundColor Yellow
}

Write-Host "`nPresiona Enter para salir..."
Read-Host
