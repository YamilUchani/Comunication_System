# Guía Completa: Desplegar Backend en Railway

## Paso 1: Preparar el Proyecto

### 1.1 Verificar que tienes estos archivos en `backend/`:

- ✅ `package.json`
- ✅ `server.js`
- ✅ `.env.example` (para referencia)
- ✅ Carpetas: `config/`, `routes/`, `middleware/`, `services/`

### 1.2 Crear archivo `.gitignore` en `backend/`

```
node_modules/
.env
*.log
.DS_Store
```

## Paso 2: Subir Código a GitHub

```bash
cd backend
git init
git add .
git commit -m "Initial backend setup for Railway"
git branch -M main
git remote add origin <TU_REPO_GITHUB>
git push -u origin main
```

## Paso 3: Configurar Railway

### 3.1 Crear Proyecto en Railway

1. Ve a https://railway.app/
2. Haz clic en **"New Project"**
3. Selecciona **"Deploy from GitHub repo"**
4. Autoriza Railway a acceder a tu GitHub
5. Selecciona el repositorio del backend

### 3.2 Configurar Variables de Entorno

En Railway, ve a tu proyecto → **Variables** y agrega:

```env
SUPABASE_URL=https://tcbmlktpzshltvmoirjs.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjYm1sa3RwenNobHR2bW9pcmpzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI4MjM0NjQsImV4cCI6MjA0ODM5OTQ2NH0.uYs8bkLF8m5ZZ8D0kpocztA
SUPABASE_SERVICE_ROLE_KEY=<TU_SERVICE_ROLE_KEY_AQUI>
AGORA_APP_ID=21feb8d8a158418c9aa3c6dfb9132451
AGORA_APP_CERTIFICATE=c8bc6f039add4d7391c0cbd92a0fa9b3
PORT=3000
NODE_ENV=production
ALLOWED_ORIGINS=*
```

**IMPORTANTE**: Reemplaza `<TU_SERVICE_ROLE_KEY_AQUI>` con tu clave real de Supabase.

### 3.3 Configurar el Build

Railway debería detectar automáticamente que es un proyecto Node.js. Si no:

1. Ve a **Settings** → **Build Command**
2. Pon: `npm install`
3. Ve a **Start Command**
4. Pon: `node server.js`

### 3.4 Configurar el Root Directory

Si tu backend está en una subcarpeta:

1. Ve a **Settings** → **Root Directory**
2. Pon: `backend`

## Paso 4: Obtener la URL de Railway

1. Una vez desplegado, Railway te dará una URL como: `https://tu-proyecto.up.railway.app`
2. Copia esa URL

## Paso 5: Actualizar Flutter `.env`

En el archivo `.env` de la raíz del proyecto Flutter:

```env
BACKEND_URL=https://tu-proyecto.up.railway.app/api
```

**Nota**: Asegúrate de agregar `/api` al final.

## Paso 6: Verificar el Despliegue

### 6.1 Probar el endpoint de salud

Abre en tu navegador:
```
https://tu-proyecto.up.railway.app/api/health
```

Deberías ver:
```json
{
  "status": "OK",
  "timestamp": "2024-...",
  "environment": "production"
}
```

### 6.2 Ver logs en Railway

1. Ve a tu proyecto en Railway
2. Haz clic en **Deployments**
3. Selecciona el deployment activo
4. Haz clic en **View Logs**

Deberías ver:
```
🚀 Servidor corriendo en puerto 3000
📊 Entorno: production
🔒 CORS habilitado para: *
```

## Paso 7: Actualizar Código en Railway

Cada vez que hagas cambios:

```bash
cd backend
git add .
git commit -m "Descripción del cambio"
git push
```

Railway automáticamente detectará el push y redesplegará.

## Troubleshooting

### Error: "Cannot find module"
- **Causa**: Falta alguna dependencia en `package.json`
- **Solución**: Agrega la dependencia y haz push

### Error: "EADDRINUSE"
- **Causa**: Railway ya está usando el puerto
- **Solución**: Usa `process.env.PORT` en `server.js` (ya lo tienes)

### Error: "Invalid API key"
- **Causa**: `SUPABASE_SERVICE_ROLE_KEY` no está configurada o es incorrecta
- **Solución**: Verifica las variables de entorno en Railway

### App Flutter no conecta
- **Causa**: `BACKEND_URL` incorrecta o falta `/api`
- **Solución**: Verifica que sea `https://tu-proyecto.up.railway.app/api`

## Comandos Útiles

### Ver logs en tiempo real (Railway CLI)
```bash
railway logs
```

### Conectar a Railway desde terminal
```bash
npm install -g @railway/cli
railway login
railway link
```

### Forzar redespliegue
En Railway Dashboard → **Deployments** → **Redeploy**

## Checklist Final

- [ ] Código subido a GitHub
- [ ] Proyecto creado en Railway
- [ ] Variables de entorno configuradas
- [ ] Build exitoso (ver logs)
- [ ] `/api/health` responde correctamente
- [ ] `BACKEND_URL` actualizada en Flutter `.env`
- [ ] Hot Restart en Flutter
- [ ] Usuarios y reuniones se cargan correctamente
