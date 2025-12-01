# Script para desregistrar el protocolo stemforall
# Útil si necesitas limpiar el registro o cambiar de aplicación

Write-Host "Desregistrando el protocolo stemforall..." -ForegroundColor Cyan

# Verificar si la clave existe
$keyPath = "Registry::HKEY_CLASSES_ROOT\stemforall"
if (Test-Path $keyPath) {
    try {
        # Eliminar la clave del registro
        Remove-Item -Path $keyPath -Recurse -Force
        Write-Host "✓ Protocolo stemforall desregistrado exitosamente" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Error al desregistrar el protocolo: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Intenta ejecutar este script como administrador" -ForegroundColor Yellow
        exit 1
    }
}
else {
    Write-Host "⚠️ El protocolo stemforall no estaba registrado" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Limpieza completada" -ForegroundColor Green
