# Cómo generar el instalador de edu_mi_app

## Pasos:

1. **Hacer el build de Flutter:**
   ```bash
   flutter build windows
   ```
   Esto genera el ejecutable en `build\windows\x64\runner\Release\edu_mi_app.exe`

2. **Compilar el instalador con Inno Setup:**
   - Abrí `setup_script.iss` con Inno Setup Compiler
   - O ejecutá desde línea de comandos:
   ```bash
   iscc setup_script.iss
   ```

3. **El instalador se genera en:**
   `edu_mi_app\installer\installer_output\EduMiApp_Installer_v1.0.0.exe`

## Qué incluye el instalador:

- ✅ Registro del protocolo `stemforall://` en Windows
- ✅ Instalación de Visual C++ Redistributable (si falta)
- ✅ Accesos directos en Menú Inicio y Escritorio
- ✅ Desinstalador limpio
- ✅ Todos los archivos necesarios (DLLs, assets, simuladores)

## Nota importante:

El protocolo `stemforall://` ya está registrado en el script. Cuando un usuario haga clic en un link `stemforall://estudiante/123`, Windows abrirá la app automáticamente.