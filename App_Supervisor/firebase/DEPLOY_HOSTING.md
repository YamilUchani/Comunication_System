# 🚀 Deploy de Firebase Hosting para App_Supervisor

## 📋 Resumen

Esta guía explica cómo desplegar la página de callback OAuth de Google para **App_Supervisor** (EduCoParent) en Firebase Hosting.

## 🌐 URL de Hosting

**URL Actual:** `https://educoparent-callback.web.app` (crear en Firebase)

---

## 📁 Estructura

```
App_Supervisor/firebase/
├── public/
│   ├── index.html        # Página de callback OAuth
│   └── 404.html          # Página de error 404
├── functions/
│   └── index.js          # Cloud Functions (opcional)
├── firebase.json         # Configuración de Firebase
└── .gitignore
```

---

## 🔧 Pasos de Configuración

### Paso 1: Inicializar Firebase Hosting

```bash
# Navegar a la carpeta firebase de App_Supervisor
cd App_Supervisor/firebase

# Inicializar Firebase (si es la primera vez)
firebase init hosting

# Seleccionar:
# - Use an existing project: [Tu proyecto de Firebase]
# - Public directory: public
# - Configure as SPA: No
# - GitHub deploys: No
```

### Paso 2: Configurar URL de Callback en Supabase

1. Ve a tu proyecto en Supabase: https://app.supabase.com
2. Ve a **Authentication** > **URL Configuration**
3. En **Redirect URLs**, agrega:
   ```
   https://educoparent-callback.web.app
   ```
4. Guarda los cambios

### Paso 3: Configurar OAuth en Google Cloud Console

1. Ve a https://console.cloud.google.com
2. Selecciona tu proyecto Firebase
3. Ve a **APIs & Services** > **Credentials**
4. Edita tu OAuth 2.0 Client ID
5. En **Authorized redirect URIs**, agrega:
   ```
   https://educoparent-callback.web.app
   https://educoparent-callback.web.app/__/auth/handler
   ```

### Paso 4: Actualizar redirectTo en App_Supervisor

Edita `App_Supervisor/js/app-supervisor-config.js`:

```javascript
window.APP_SUPERVISOR_CONFIG = {
  supabaseUrl: "https://tcbmlktpzshltvmoirjs.supabase.co",
  supabaseAnonKey: "TU_ANON_KEY_AQUI",
  appUrl: "https://educoparent-callback.web.app",  // ← URL de callback
  // ... resto de la configuración
};
```

### Paso 5: Desplegar a Firebase Hosting

```bash
# Desde la carpeta App_Supervisor/firebase
firebase deploy --only hosting

# O desplegar todo (hosting + functions)
firebase deploy
```

### Paso 6: Verificar el despliegue

1. Abre https://educoparent-callback.web.app
2. Deberías ver la página de EduCoParent con el logo
3. Abre DevTools (F12) para ver los logs

---

## 🔄 Flujo de Autenticación Completo

```
Usuario en App_Supervisor
    ↓
1. Click en "Continuar con Google"
    ↓
2. Supabase OAuth redirige a Google
    ↓
3. Google autoriza y redirige a:
   https://educoparent-callback.web.app?access_token=...&refresh_token=...
    ↓
4. Página callback procesa el token
    ↓
5. Construye deep link:
   educoparent://auth-callback?access_token=...&refresh_token=...
    ↓
6. Abre la app de escritorio App_Supervisor
    ↓
7. App procesa el token y completa el login
```

---

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

---

## 🚀 Desplegar

```bash
# Desplegar hosting
firebase deploy --only hosting

# Ver URL desplegada
firebase hosting:sites:list
```

---

## 📊 Monitoreo

### Ver logs de acceso:

```bash
# Logs de hosting
firebase hosting:channel:list

# Analytics (si está habilitado)
# Ve a Firebase Console > Analytics
```

---

## 🔐 Seguridad

### Headers de Seguridad

El `firebase.json` incluye:
```json
{
  "headers": [{
    "key": "Cache-Control",
    "value": "no-cache, no-store, must-revalidate"
  }]
}
```

### Prevención de ataques:

- ✅ No se almacenan tokens en localStorage
- ✅ Tokens se pasan inmediatamente a la app
- ✅ URL se limpia después de procesar
- ✅ HTTPS obligatorio (Firebase)

---

## 🐛 Debugging

### Activar modo debug:

En `public/index.html`, línea ~72:
```javascript
const DEBUG_MODE = true; // Cambiar a true
```

Esto mostrará:
- Logs detallados en consola
- Panel de debug en la UI
- Tokens visibles (solo para desarrollo)

### Ver qué está recibiendo la página:

1. Abre https://educoparent-callback.web.app
2. Abre DevTools (F12)
3. Ve a la pestaña Console
4. Verás logs como:
   ```
   [AUTH-CALLBACK] Página cargada {url: "...", search: "...", hash: "..."}
   [AUTH-CALLBACK] Parámetros extraídos {...}
   [AUTH-CALLBACK] Deep link construido "educoparent://..."
   ```

---

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

1. Verifica que el protocolo `educoparent://` esté registrado
2. Verifica permisos en Windows
3. Usa el botón "Abrir EduCoParent" como backup

### Aparece "No se detectaron parámetros"

1. Verifica que Supabase esté redirigiendo a la URL correcta
2. Verifica que la URL de callback esté configurada en Supabase
3. Revisa los logs en DevTools

---

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

---

## 🔗 Enlaces Útiles

- [Firebase Hosting Docs](https://firebase.google.com/docs/hosting)
- [Supabase OAuth](https://supabase.com/docs/guides/auth/social-login)
- [Custom Domains](https://firebase.google.com/docs/hosting/custom-domain)

---

**Versión actual**: Creada para App_Supervisor (EduCoParent)
**Última actualización**: Junio 2025