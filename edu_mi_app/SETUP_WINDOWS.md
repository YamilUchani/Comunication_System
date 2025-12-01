# Configuración Rápida - Windows

## 🚀 Inicio Rápido

### Paso 1: Instalar Visual Studio

**DESCARGA:** https://visualstudio.microsoft.com/downloads/

1. Descarga **Visual Studio Community 2022** (gratis)
2. Durante la instalación, selecciona: **"Desarrollo para el escritorio con C++"**
3. Espera a que termine la instalación (~30-60 min)

### Paso 2: Verificar Instalación

Abre PowerShell y ejecuta:

```powershell
flutter doctor -v
```

### Paso 3: Instalar Dependencias del Proyecto

```powershell
cd "G:\Github\Software de administracion\Comunication_System\edu_mi_app"
flutter pub get
```

### Paso 4: Ejecutar la Aplicación

```powershell
flutter run -d windows
```

## ✅ Checklist

- [ ] Visual Studio Community 2022 instalado
- [ ] Workload "Desktop development with C++" seleccionado
- [ ] PowerShell reiniciado
- [ ] `flutter doctor` muestra Visual Studio como instalado
- [ ] `flutter pub get` ejecutado sin errores
- [ ] Aplicación ejecutándose con `flutter run -d windows`

## 📋 Requisitos del Sistema

- Windows 10 o superior ✅ (tienes Windows 11)
- Flutter SDK ✅ (instalado)
- Visual Studio 2022 ❌ (necesitas instalarlo)
- Espacio en disco: ~20 GB para Visual Studio

## 🔧 Comandos Útiles

```powershell
# Ver estado de Flutter
flutter doctor -v

# Limpiar proyecto
flutter clean

# Actualizar dependencias
flutter pub get

# Ejecutar en Windows
flutter run -d windows

# Ejecutar en modo release (más rápido)
flutter run -d windows --release
```

## 🆘 Ayuda

Si tienes problemas, revisa el archivo de diagnóstico completo o contacta al equipo de desarrollo.
