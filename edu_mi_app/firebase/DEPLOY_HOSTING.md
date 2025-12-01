# Guía Rápida: Firebase Hosting para OAuth Callback

## 🎯 ¿Qué es esto?

Tu URL actual: **https://stemforall-f57ac.firebaseapp.com**

Es la página que recibe el callback de Google/Supabase OAuth y redirige a tu app de escritorio.

## ⚡ Despliegue Rápido

### 1. Desplegar la nueva versión mejorada

```bash
# Desde la raíz del proyecto
cd "G:\Github\Software de administracion\Comunication_System\edu_mi_app"

# Desplegar hosting
firebase deploy --only hosting
```

Verás:
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/stemforall-f57ac/overview
Hosting URL: https://stemforall-f57ac.firebaseapp.com
```

### 2. Configurar URLs de Callback

#### En Supabase:

1. Ve a https://supabase.com/dashboard
2. Selecciona tu proyecto
3. Ve a **Authentication** > **URL Configuration**
4. En **Redirect URLs**, agrega:
   ```
   https://stemforall-f57ac.firebaseapp.com
   ```
5. Guarda

#### En Google Cloud Console:

1. Ve a https://console.cloud.google.com
2. Selecciona tu proyecto
3. **APIs & Services** > **Credentials**
4. Edita tu **OAuth 2.0 Client ID**
5. En **Authorized redirect URIs**, asegúrate que estén:
   ```
   https://stemforall-f57ac.firebaseapp.com
   https://stemforall-f57ac.firebaseapp.com/__/auth/handler
   ```

### 3. Probar

1. Desde tu app Flutter, inicia Google Sign-In
2. Debería redirigir a Firebase Hosting
3. La página debería:
   - ✅ Mostrar "¡Autenticación exitosa!"
   - ✅ Abrir tu app automáticamente
   - ✅ Pasar el token a la app

## 🔍 Debugging

### Ver qué está pasando:

1. Abre https://stemforall-f57ac.firebaseapp.com manualmente
2. Abre DevTools (F12)
3. Ve a Console
4. Intenta un login desde tu app
5. Verás logs detallados

### Simular callback:

Navega a:
```
https://stemforall-f57ac.firebaseapp.com?access_token=test_123&refresh_token=refresh_456&expires_in=3600
```

Deberías ver:
- ✅ Mensaje de éxito
- ✅ Intento de abrir la app
- ✅ Token mostrado (en modo debug)

## 📊 Mejoras de la Nueva Versión

| Característica | Antes | Ahora |
|----------------|-------|-------|
| UI/UX | Básica | ✅ Profesional con estados |
| Debug | Limitado | ✅ Logs detallados |
| Manejo de errores | NO | ✅ Detección y display |
| Deep link | 1 método | ✅ 3 métodos de retry |
| Tokens múltiples | Solo access_token | ✅ access, refresh, code |
| Prevención de loops | NO | ✅ Limpieza de URL |

## 🚨 Problemas Comunes

### "La app no se abre"

1. Verifica que `stemforall://` esté registrado:
   ```bash
   .\reg\register_protocol.ps1
   ```

2. Prueba manualmente:
   ```
   Presiona Win+R
   Escribe: stemforall://test
   [Enter]
   ```
   La app debería abrirse.

### "No se detectaron parámetros"

1. Verifica la URL de callback en Supabase
2. Asegúrate que sea EXACTAMENTE: `https://stemforall-f57ac.firebaseapp.com`
3. Sin `/` al final
4. Con `https://`

### "CORS error"

No debería pasar porque Firebase Hosting automáticamente maneja CORS correctamente.

## 🔄 Actualización

Para actualizar la página en el futuro:

```bash
# 1. Editar
# Abre: firebase/public/index.html
# Haz tus cambios

# 2. Desplegar
firebase deploy --only hosting

# 3. Verificar
# Abre: https://stemforall-f57ac.firebaseapp.com
# Presiona Ctrl+F5 para refrescar sin caché
```

## 📝 Siguiente Paso

Prueba el flujo completo:

1. Desde tu app Flutter
2. Haz clic en "Continuar con Google"
3. Inicia sesión
4. Deberías regresar automáticamente a tu app

Si funciona → ¡Listo! 🎉  
Si no funciona → Revisa los logs en DevTools

---

**URL de tu página**: https://stemforall-f57ac.firebaseapp.com  
**Documentación completa**: `firebase/HOSTING_README.md`
