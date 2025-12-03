# Despliegue Rápido en Railway - Paso a Paso

## ✅ Ya hicimos: Código subido a GitHub

Tu repo: https://github.com/YamilUchani/Comunication_System

## 🚀 Ahora: Desplegar en Railway (5 minutos)

### Paso 1: Ir a Railway

Ya se abrió antes, pero si cerraste la página:
https://railway.app

### Paso 2: Login

- Haz clic en **"Login"** o **"Start a New Project"**
- Autentica con **GitHub**
- Autoriza Railway a acceder a tus repos

### Paso 3: Crear Proyecto

1. Haz clic en **"New Project"**
2. Selecciona **"Deploy from GitHub repo"**
3. Busca y selecciona: **`YamilUchani/Comunication_System`**

### Paso 4: Configurar el Backend

Railway detectará el proyecto, pero necesita saber dónde está el backend:

1. Después de seleccionar el repo, Railway creará el proyecto
2. Ve a **Settings** (engranaje)
3. En **"Root Directory"**, escribe:
   ```
   edu_mi_app/backend
   ```
4. En **"Start Command"** (si pregunta), escribe:
   ```
   npm start
   ```

### Paso 5: Variables de Entorno

1. Ve a la pestaña **"Variables"**
2. Haz clic en **"RAW Editor"** (más fácil)
3. Pega esto (reemplaza con TUS valores):

```
NODE_ENV=production
PORT=3000
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_KEY=tu_service_role_key_de_supabase
AGORA_APP_ID=tu_app_id_de_agora
AGORA_APP_CERTIFICATE=tu_certificado_de_agora
ALLOWED_ORIGINS=*
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
TOKEN_EXPIRATION_TIME=3600
```

**Dónde obtener:**
- **Supabase**: https://supabase.com → Settings → API
  - Copia: URL y **service_role** key
- **Agora**: https://console.agora.io → Tu proyecto
  - Copia: App ID y Primary Certificate

4. Haz clic en **"Add"** o **"Deploy"**

### Paso 6: Esperar Deploy

Railway comenzará a desplegar automáticamente. Verás:
```
Installing dependencies...
npm install
Building...
Starting server...
✓ Deployed
```

Esto toma ~2-3 minutos.

### Paso 7: Obtener URL

1. Ve a **Settings** → **Networking**
2. En **"Public Networking"**, haz clic en **"Generate Domain"**
3. Copia la URL que aparece, por ejemplo:
   ```
   https://comunication-system-production-xxxx.up.railway.app
   ```

### Paso 8: Verificar

Prueba tu API:

```powershell
curl https://TU-URL-DE-RAILWAY.up.railway.app/api/health
```

Deberías ver:
```json
{
  "status": "OK",
  "timestamp": "...",
  "environment": "production"
}
```

## ✅ ¡Listo! Backend Desplegado

Ahora actualiza Flutter para usarlo.

---

**Siguiente:** Actualizar `.env` de Flutter con la URL de Railway
