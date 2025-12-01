# Registro del Protocolo StemForAll

Este directorio contiene los scripts para registrar y desregistrar el protocolo de URL personalizado `stemforall://` que permite que la aplicación maneje deep links.

## Uso

### Registrar el protocolo (Recomendado)

Ejecuta el script PowerShell que detecta automáticamente la ubicación del `.exe`:

```powershell
# Para la versión Release (recomendado para producción)
.\reg\register_protocol.ps1

# O para la versión Debug (solo para desarrollo)
.\reg\register_protocol.ps1 -BuildType Debug
```

**Importante:** Debes compilar la aplicación antes de registrar el protocolo:

```powershell
flutter build windows --release
```

### Desregistrar el protocolo

Si necesitas limpiar el registro:

```powershell
.\reg\unregister_protocol.ps1
```

## ¿Qué hace el script?

El script `register_protocol.ps1`:

1. Detecta automáticamente la ruta del proyecto
2. Busca el ejecutable en `build\windows\x64\runner\Release\edu_mi_app.exe` (o Debug)
3. Crea un archivo `.reg` temporal con la ruta correcta
4. Registra el protocolo en el registro de Windows
5. Verifica que el protocolo se haya registrado correctamente

## Archivo .reg Manual (No Recomendado)

El archivo `register_stemforall.reg` es un ejemplo de registro manual, pero **no se recomienda usarlo** porque tiene una ruta hardcodeada que probablemente no coincida con tu sistema.

Si prefieres usar un archivo `.reg` manual, actualiza la línea 12 con la ruta correcta a tu ejecutable.

## Prueba del Protocolo

Después de registrar el protocolo, puedes probarlo:

1. Abre el navegador
2. Ve a la URL: `stemforall://callback?access_token=test&type=recovery`
3. Debería abrir tu aplicación automáticamente

## Notas

- El script requiere permisos de administrador para modificar el registro
- El protocolo se registra en `HKEY_CLASSES_ROOT\stemforall`
- La aplicación debe estar compilada antes de registrar el protocolo
