# Configuración de Firebase Hosting y OAuth Callback

## 📋 Resumen

Esta carpeta contiene los archivos para Firebase Hosting que maneja el callback de autenticación OAuth de Supabase/Google.

## 🌐 URL de Hosting

**URL Actual**: https://stemforall-f57ac.firebaseapp.com

## 📁 Estructura

```
firebase/
├── public/
│   ├── index.html        # Página de callback OAuth (mejorada)
│   └── 404.html          # Página de error 404
├── functions/
│   └── index.js          # Cloud Functions
└── firebase.json         # Configuración de Firebase
```

## 🔧 Configuración

### Paso 1: Habilitar Firebase Hosting

```bash
# Si no lo has hecho, inicializa Hosting
firebase init hosting

# Seleccionar:
# - Public directory: public
# - Configure as SPA: No
# - GitHub deploys: No
```

### Paso 2: Desplegar Hosting

```bash
# Desplegar solo hosting
firebase deploy --only hosting

# O desplegar todo (hosting + functions)
firebase deploy
```

### Paso 3: Configurar URL de Callback en Supabase

1. Ve a tu proyecto en Supabase
2. Ve a **Authentication** > **URL Configuration**
3. Agrega en **Redirect URLs**:
   ```
   https://stemforall-f57ac.firebaseapp.com
   ```

### Paso 4: Configurar OAuth en Google Cloud Console

1. Ve a https://console.cloud.google.com
2. Selecciona tu proyecto Firebase
3. Ve a **APIs & Services** > **Credentials**
4. Edita tu OAuth 2.0 Client ID
5. En **Authorized redirect URIs**, agrega:
   ```
   https://stemforall-f57ac.firebaseapp.com
   https://stemforall-f57ac.firebaseapp.com/__/auth/handler
   ```

## 🔄 Flujo de Autenticación

```
Usuario en App
     ↓
1. Inicia Google Sign-In
     ↓
Google OAuth
     ↓
2. Redirige a Firebase Hosting
   https://stemforall-f57ac.firebaseapp.com?access_token=...
     ↓
3. Página extrae token
     ↓
4. Construye deep link
   stemforall://auth-callback?access_token=...
     ↓
5. Abre la app de escritorio
     ↓
6. App procesa el token
   (DeepLinkService.handleDeepLink)
```

## 📄 Archivo index.html Mejorado

### Características:

✅ **Extracción robusta de tokens**
- Soporta `access_token`, `refresh_token`, `code`
- Lee de query params y hash fragments
- Maneja errores de OAuth

✅ **Deep Links mejorados**
- Construye URLs correctas para Windows
- Múltiples métodos de apertura (location, iframe, window.open)
- Retry automático

✅ **UI/UX mejorada**
- Estados visuales claros (loading, success, error)
- Animaciones suaves
- Modo debug con logs detallados

✅ **Prevención de loops infinitos**
- Limpia URL después de procesar
- Previene recargas accidentales

## 🧪 Probar Localmente

```bash
# Servir localmente
firebase serve --only hosting

# Visitar
http://localhost:5000
```

### Simular callback:

```
http://localhost:5000?access_token=test_token_123&refresh_token=test_refresh&expires_in=3600
```

## 🚀 Desplegar

```bash
# Desplegar hosting
firebase deploy --only hosting

# Ver URL desplegada
firebase hosting:sites:list
```

## 📊 Monitoreo

### Ver logs de acceso:

```bash
# Logs de hosting
firebase hosting:channel:list

# Analytics (si está habilitado)
# Ve a Firebase Console > Analytics
```

## 🔐 Seguridad

### Headers de Seguridad

El `firebase.json` ya incluye:
```json
{
  "headers": [{
    "source": "**",
    "headers": [{
      "key": "Cache-Control",
      "value": "no-cache, no-store, must-revalidate"
    }]
  }]
}
```

### Prevención de ataques:

- ✅ No se almacenan tokens en localStorage
- ✅ Tokens se pasan inmediatamente a la app
- ✅ URL se limpia después de procesar
- ✅ HTTPS obligatorio (Firebase)

## 🐛 Debugging

### Activar modo debug:

En `index.html`, línea ~72:
```javascript
const DEBUG_MODE = true; // Cambiar a true
```

Esto mostrará:
- Logs detallados en consola
- Panel de debug en la UI
- Tokens visibles (solo para desarrollo)

### Ver qué está recibiendo la página:

1. Abre https://stemforall-f57ac.firebaseapp.com
2. Abre DevTools (F12)
3. Ve a la pestaña Console
4. Verás logs como:
   ```
   [AUTH] Página cargada {url: "...", search: "...", hash: "..."}
   [AUTH] Parámetros extraídos {...}
   [AUTH] Deep link construido "stemforall://..."
   ```

## ❓ FAQ

### ¿Por qué necesito Firebase Hosting?

Para que Supabase/Google OAuth pueda redirigir a una URL HTTPS válida. Las apps de escritorio no pueden recibir callbacks OAuth directamente.

### ¿Puedo usar otro dominio?

Sí, puedes conectar un dominio personalizado:
```bash
firebase hosting:sites:create mi-dominio
firebase target:apply hosting production mi-dominio
```

### La app no se abre automáticamente

1. Verifica que el protocolo `stemforall://` esté registrado (ejecuta `reg/register_protocol.ps1`)
2. Verifica permisos en Windows
3. Usa el botón "Copiar token" como backup

### Aparece "No se detectaron parámetros"

1. Verifica que Supabase esté redirigiendo a la URL correcta
2. Verifica que la URL de callback esté configurada en Supabase
3. Revisa los logs en DevTools

## 📝 Próximos Pasos

1. **Custom Domain** (opcional):
   - Registrar dominio propio
   - Conectar a Firebase Hosting
   - Actualizar URLs de callback

2. **Analytics**:
   - Habilitar Google Analytics
   - Trackear conversiones de auth

3. **A/B Testing**:
   - Probar diferentes diseños de la página

## 🔗 Enlaces Útiles

- [Firebase Hosting Docs](https://firebase.google.com/docs/hosting)
- [Supabase OAuth](https://supabase.com/docs/guides/auth/social-login)
- [Custom Domains](https://firebase.google.com/docs/hosting/custom-domain)

---

**Versión actual**: Mejorada con debugging, mejor UX y manejo robusto de errores
**Última actualización**: Noviembre 2024
