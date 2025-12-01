# Despliegue en Railway - 100% Gratis (Sin Tarjeta)

## ✅ Por qué Railway

- ✅ **Completamente gratis** (500 horas/mes = ~20 días)
- ✅ **No requiere tarjeta de crédito**
- ✅ **Deploy automático desde GitHub**
- ✅ **URL HTTPS gratis**
- ✅ **Variables de entorno fáciles**

## 🚀 Paso a Paso

### 1. Crear Cuenta en Railway

1. Ve a: https://railway.app
2. Haz clic en "**Start a New Project**" o "**Login**"
3. Autentica con **GitHub** (recomendado)

### 2. Subir Código a GitHub

Primero necesitamos que tu código esté en GitHub:

```powershell
# Si no has inicializado git
cd "G:\Github\Software de administracion\Comunication_System\edu_mi_app"
git init
git add .
git commit -m "Backend con Firebase y Supabase"

# Si ya tienes repositorio, solo push
git add .
git commit -m "Add backend for Railway"
git push origin main
```

### 3. Crear Proyecto en Railway

1. En Railway, haz clic en "**New Project**"
2. Selecciona "**Deploy from GitHub repo**"
3. Autoriza Railway a acceder a tus repos (si es primera vez)
4. Selecciona tu repositorio `Comunication_System`

### 4. Configurar Root Directory

Railway detectará automáticamente que es Node.js, pero necesita saber dónde está el backend:

1. En tu proyecto de Railway
2. Ve a **Settings**
3. En "**Root Directory**", pon: `edu_mi_app/backend`
4. En "**Start Command**", pon: `npm start`

### 5. Agregar Variables de Entorno

1. En tu proyecto, ve a **Variables**
2. Agrega estas variables (haz clic en "+ New Variable" para cada una):

```env
NODE_ENV=production
PORT=3000

SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_KEY=tu_service_key

AGORA_APP_ID=tu_app_id
AGORA_APP_CERTIFICATE=tu_certificado

ALLOWED_ORIGINS=*
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
TOKEN_EXPIRATION_TIME=3600
```

**Dónde obtener las credenciales:**
- **Supabase**: https://supabase.com/dashboard → Settings → API
- **Agora**: https://console.agora.io → Tu proyecto → Config

### 6. Deploy Automático

Railway desplegará automáticamente. Espera ~2-3 minutos.

Verás en los logs:
```
Installing dependencies...
Building...
Starting...
✓ Deployed successfully
```

### 7. Obtener URL

1. En tu proyecto, ve a **Settings** → **Networking**
2. Haz clic en "**Generate Domain**"
3. Copia la URL: `https://tu-proyecto.up.railway.app`

### 8. Verificar que Funciona

```powershell
# Probar health check
curl https://tu-proyecto.up.railway.app/health
```

Deberías ver:
```json
{
  "status": "OK",
  "timestamp": "...",
  "environment": "production"
}
```

## 📱 Actualizar Flutter para Usar Railway

### 1. Actualizar .env del cliente

Edita `edu_mi_app/.env`:

```env
# Backend URL (Railway)
BACKEND_URL=https://tu-proyecto.up.railway.app/api

# Supabase (para auth y DB)
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=tu_anon_key

# Agora (solo App ID)
AGORA_APP_ID=tu_app_id
```

### 2. Verificar meeting_service.dart

Abre `lib/services/meeting_service.dart` y verifica que use la URL del .env:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MeetingService {
  static final String baseUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000/api';
  // ...
}
```

## 🧪 Probar Todo el Flujo

### 1. Desde la App

```powershell
cd "G:\Github\Software de administracion\Comunication_System\edu_mi_app"
flutter run -d windows
```

### 2. Crear Reunión

Desde tu app:
1. Inicia sesión
2. Intenta crear una reunión
3. Debería llamar a Railway y obtener un token de Agora

### 3. Verificar en Supabase

Ve a Supabase → Table Editor → `meetings`  
Deberías ver las reuniones creadas

## 💰 Límites Gratis de Railway

- **500 horas/mes** de ejecución
- **100 GB/mes** de bandwidth
- **1 GB RAM** por servicio
- **1 GB storage**

Para una app educativa inicial: **MÁS que suficiente** ✅

## 🔄 Actualizar el Backend

Cuando hagas cambios:

```powershell
git add .
git commit -m "Actualización del backend"
git push origin main
```

Railway redesplegará automáticamente en ~2 minutos.

## 📊 Ver Logs

En Railway:
1. Tu proyecto → **Deployments**
2. Haz clic en el deployment activo
3. Ve **View Logs**

## ⚡ Alternativa: Render (También Gratis)

Si Railway no funciona, Render es otra opción 100% gratis:

1. Ve a https://render.com
2. "New +" → "Web Service"
3. Conecta GitHub
4. Root Directory: `edu_mi_app/backend`
5. Build: `npm install`
6. Start: `npm start`
7. Plan: **Free**

## ❓ FAQ

**¿Se dormirá el servidor?**  
Sí, después de 15-30 min de inactividad puede tardar ~2-3 seg en despertar la primera vez.

**¿Necesito actualizar algo en Firebase?**  
No, Firebase Hosting sigue funcionando para el callback OAuth. Solo las Cloud Functions las reemplazamos por Railway.

**¿Puedo usar ambos (Firebase + Railway)?**  
Sí, puedes usar:
- Firebase Hosting → Callback OAuth
- Firebase Auth → Google Sign-In  
- Railway → API de reuniones
- Supabase → Base de datos

---

## ✅ Checklist Final

- [ ] Cuenta de Railway creada
- [ ] Código subido a GitHub
- [ ] Proyecto creado en Railway
- [ ] Root directory configurado: `edu_mi_app/backend`
- [ ] Variables de entorno agregadas
- [ ] Deploy exitoso
- [ ] URL generada y copiada
- [ ] `.env` de Flutter actualizado con URL de Railway
- [ ] App probada y reuniones funcionando

**¡Listo! Backend gratis sin tarjeta de crédito funcionando! 🎉**
