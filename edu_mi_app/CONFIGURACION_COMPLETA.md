# Guía Completa de Configuración - EduMi App Backend

## 📚 Índice

1. [Introducción](#introducción)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [Requisitos Previos](#requisitos-previos)
4. [Configuración de Supabase](#configuración-de-supabase)
5. [Configuración del Backend](#configuración-del-backend)
6. [Despliegue del Backend](#despliegue-del-backend)
7. [Configuración del Cliente Flutter](#configuración-del-cliente-flutter)
8. [Pruebas y Verificación](#pruebas-y-verificación)
9. [FAQ y Solución de Problemas](#faq-y-solución-de-problemas)

---

## Introducción

### ¿Qué es este backend?

El backend que creamos es un **servidor de autenticación y autorización** para reuniones de video. **NO es un servidor de señalización** porque Agora RTC maneja toda la señalización internamente.

### ¿Qué hace el backend?

- ✅ Verifica la identidad del usuario (autenticación con Supabase)
- ✅ Verifica permisos (¿puede crear reuniones?)
- ✅ Genera tokens seguros de Agora
- ✅ Gestiona el ciclo de vida de reuniones
- ✅ Registra participantes y actividad

### ¿Qué hace Agora?

- ✅ Maneja toda la señalización (conexión entre usuarios)
- ✅ Transmite audio/video en tiempo real
- ✅ Gestiona la calidad de red
- ✅ Codifica/decodifica media

---

## Arquitectura del Sistema

```
┌─────────────────┐
│  Cliente Flutter│
│   (Tu App)      │
└────────┬────────┘
         │
         │ 1. Solicita crear/unirse a reunión
         │    (con JWT de Supabase)
         ↓
┌─────────────────┐
│  Tu Backend     │
│  (Node.js)      │ ← Aquí se protegen las credenciales
├─────────────────┤
│ - Verifica JWT  │
│ - Verifica      │
│   permisos      │
│ - Genera token  │
│   de Agora      │
└────────┬────────┘
         │
         │ 2. Retorna token de Agora
         ↓
┌─────────────────┐
│  Cliente Flutter│
│   (Tu App)      │
└────────┬────────┘
         │
         │ 3. Se conecta con el token
         ↓
┌─────────────────┐
│  Agora Cloud    │ ← Servidor de señalización
│  (Automático)   │    y streaming de Agora
├─────────────────┤
│ - Señalización  │
│ - P2P/Relay     │
│ - Audio/Video   │
└─────────────────┘
```

---

## Requisitos Previos

### 1. Cuentas Necesarias

- [ ] **Supabase** (gratuita): https://supabase.com
- [ ] **Agora** (gratuita con límites): https://console.agora.io
- [ ] **Hosting para backend** (una de estas):
  - Railway (gratuita): https://railway.app
  - Render (gratuita): https://render.com
  - Heroku (requiere tarjeta)
  - DigitalOcean (paga)

### 2. Software Necesario

- [ ] Node.js >= 18.0.0
- [ ] Git
- [ ] Flutter SDK
- [ ] Editor de código (VS Code recomendado)

---

## Configuración de Supabase

### Paso 1: Crear Proyecto en Supabase

1. Ve a https://supabase.com
2. Inicia sesión o crea cuenta
3. Haz clic en "New Project"
4. Completa:
   - **Name**: `edumi-app` (o el que prefieras)
   - **Database Password**: Crea una contraseña segura (guárdala)
   - **Region**: Selecciona la más cercana a ti
   - **Pricing Plan**: Free
5. Espera a que se cree el proyecto (~2 minutos)

### Paso 2: Configurar la Base de Datos

1. En tu proyecto de Supabase, ve a **SQL Editor**
2. Haz clic en "New query"
3. Copia y pega el contenido de `backend/database/schema.sql`
4. Haz clic en "Run" (▶️)
5. Verifica que aparezca: "Success. No rows returned"

### Paso 3: Obtener Credenciales

1. Ve a **Settings** > **API**
2. Copia estas credenciales (las necesitarás):
   - **URL**: `https://xxxxx.supabase.co`
   - **anon/public key**: Para el cliente Flutter
   - **service_role key**: Para el backend (¡nunca en el cliente!)

### Paso 4: Configurar Autenticación

1. Ve a **Authentication** > **Providers**
2. Habilita **Email** (ya debería estar habilitado)
3. Opcional: Configura **Google OAuth**:
   - Ve a **Google Cloud Console**
   - Crea OAuth 2.0 credentials
   - Copia Client ID y Secret
   - Pégalos en Supabase

### Paso 5: Configurar Políticas de Seguridad

Las políticas RLS ya fueron creadas con el script SQL, pero verifica:

1. Ve a **Database** > **Tables**
2. Haz clic en `meetings`
3. Haz clic en "Policies"
4. Deberías ver las políticas creadas

---

## Configuración del Backend

### Paso 1: Obtener Credenciales de Agora

1. Ve a https://console.agora.io
2. Inicia sesión o crea cuenta
3. Crea un nuevo proyecto:
   - **Project Name**: `EduMi App`
   - **Use Case**: Video Calling
   - **Authentication**: Secured mode (con token)
4. Una vez creado, copia:
   - **App ID**: `xxxxxxxxxxxxxxxxxxxxxxxx`
   - **App Certificate**: Haz clic en "Edit" junto a Primary Certificate y copia

### Paso 2: Configurar Variables de Entorno

1. En tu proyecto, ve a la carpeta `backend`
2. Copia `.env.example` a `.env`:
   ```bash
   cd backend
   cp .env.example .env
   ```

3. Edita `.env` con tus credenciales:
   ```env
   # Puerto del servidor
   PORT=3000
   
   # Supabase (desde Settings > API)
   SUPABASE_URL=https://xxxxx.supabase.co
   SUPABASE_SERVICE_KEY=eyJhbGc... (service_role key)
   
   # Agora (desde la consola)
   AGORA_APP_ID=tu_app_id_aqui
   AGORA_APP_CERTIFICATE=tu_certificado_aqui
   
   # Configuración
   TOKEN_EXPIRATION_TIME=3600
   NODE_ENV=development
   ALLOWED_ORIGINS=http://localhost:3000
   ```

### Paso 3: Instalar Dependencias

```bash
cd backend
npm install
```

Esto instalará:
- express
- @supabase/supabase-js
- agora-access-token
- cors, helmet, dotenv, etc.

### Paso 4: Probar Localmente

```bash
npm run dev
```

Deberías ver:
```
🚀 Servidor corriendo en puerto 3000
📊 Entorno: development
🔒 CORS habilitado para: http://localhost:3000
```

### Paso 5: Verificar que Funciona

Abre otra terminal y ejecuta:

```bash
curl http://localhost:3000/health
```

Deberías ver:
```json
{
  "status": "OK",
  "timestamp": "2024-...",
  "environment": "development"
}
```

---

## Despliegue del Backend

### Opción 1: Railway (Recomendado - Gratuito)

#### 1. Preparar el Repositorio

```bash
# En la carpeta raíz del proyecto
git add .
git commit -m "Add backend"
git push origin main
```

#### 2. Desplegar en Railway

1. Ve a https://railway.app
2. Haz clic en "Start a New Project"
3. Selecciona "Deploy from GitHub repo"
4. Autoriza Railway a acceder a tus repos
5. Selecciona tu repositorio
6. Railway detectará automáticamente Node.js

#### 3. Configurar Variables de Entorno

1. En tu proyecto de Railway, ve a **Variables**
2. Agrega **todas** las variables de tu `.env`:
   - `PORT` (Railway lo asigna automático, puedes omitir)
   - `NODE_ENV=production`
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_KEY`
   - `AGORA_APP_ID`
   - `AGORA_APP_CERTIFICATE`
   - `TOKEN_EXPIRATION_TIME=3600`
   - `ALLOWED_ORIGINS=*` (temporalmente, luego configura tu dominio)

#### 4. Configurar el Root Directory

1. En **Settings**, busca "Root Directory"
2. Establece: `backend`
3. Railway redesplegará automáticamente

#### 5. Obtener la URL

1. Ve a **Settings** > **Networking**
2. Copia la URL: `https://tu-proyecto.railway.app`
3. ¡Guárdala! La necesitarás en Flutter

#### 6. Verificar Despliegue

```bash
curl https://tu-proyecto.railway.app/health
```

---

### Opción 2: Render (Gratuito con Limitaciones)

#### 1. Crear Cuenta en Render

1. Ve a https://render.com
2. Crea cuenta con GitHub

#### 2. Crear Web Service

1. Haz clic en "New +" > "Web Service"
2. Conecta tu repositorio
3. Configura:
   - **Name**: `edumi-backend`
   - **Root Directory**: `backend`
   - **Environment**: Node
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
   - **Plan**: Free

#### 3. Agregar Variables de Entorno

En la sección "Environment", agrega todas las variables de `.env`

#### 4. Deploy

Render desplegará automáticamente. Espera ~5 minutos.

---

### Opción 3: Heroku

```bash
# Instalar Heroku CLI
# Windows: scoop install heroku-cli
# Mac: brew tap heroku/brew && brew install heroku

# Login
heroku login

# Crear app
cd backend
heroku create edumi-backend

# Configurar variables de entorno
heroku config:set NODE_ENV=production
heroku config:set SUPABASE_URL=tu_url
heroku config:set SUPABASE_SERVICE_KEY=tu_key
heroku config:set AGORA_APP_ID=tu_app_id
heroku config:set AGORA_APP_CERTIFICATE=tu_certificado

# Desplegar
git push heroku main
```

---

## Configuración del Cliente Flutter

### Paso 1: Actualizar pubspec.yaml

Agrega la dependencia `http`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.0.0
  flutter_dotenv: ^5.1.0
  agora_rtc_engine: ^6.3.0
  http: ^1.1.0  # ← Agregar esta línea
```

Ejecuta:
```bash
flutter pub get
```

### Paso 2: Actualizar .env del Cliente

Edita `edu_mi_app/.env`:

```env
# Supabase (anon key, NO service key)
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGc... (anon/public key)

# Agora (solo App ID, el certificado está en el backend)
AGORA_APP_ID=tu_app_id_aqui

# URL del Backend (cambiar según dónde lo desplegaste)
BACKEND_URL=https://tu-proyecto.railway.app/api
```

### Paso 3: Actualizar meeting_service.dart

Edita `lib/services/meeting_service.dart`:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MeetingService {
  // Leer la URL desde .env
  static final String baseUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000/api';
  
  // ... resto del código
}
```

### Paso 4: Actualizar channel_input_screen.dart

Reemplaza la generación manual de tokens por llamadas al backend:

```dart
import '../services/meeting_service.dart';

// En lugar de generar el token localmente:
// final token = 'hardcoded_token';

// Usa el servicio:
final meetingService = MeetingService();

try {
  final meeting = await meetingService.createMeeting(
    channelName: channelName,
    title: 'Reunión de $userName',
  );
  
  // Navega con el token del backend
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VideoCallScreen(
        channelName: meeting['channelName'],
        token: meeting['token'], // Token seguro del backend
        userName: userName,
      ),
    ),
  );
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

### Paso 5: Remover Credenciales del Cliente

**IMPORTANTE**: Elimina `AGORA_APP_CERTIFICATE` del `.env` del cliente si lo tenías.

Solo debe quedar:
- ✅ `AGORA_APP_ID`
- ❌ ~~`AGORA_APP_CERTIFICATE`~~ (solo en el backend)

---

## Pruebas y Verificación

### 1. Probar el Backend

#### Test Health Check
```bash
curl https://tu-backend.railway.app/health
```

Esperado:
```json
{"status":"OK","timestamp":"...","environment":"production"}
```

#### Test Crear Reunión (necesitas un JWT de Supabase)

1. Primero, obtén un JWT:
   - Inicia sesión en tu app Flutter
   - O usa Supabase Dashboard > Authentication > Users > Copia el token

2. Prueba crear reunión:
```bash
curl -X POST https://tu-backend.railway.app/api/meetings/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer tu_jwt_token_aqui" \
  -d '{
    "channelName": "test-channel",
    "title": "Test Meeting"
  }'
```

Esperado:
```json
{
  "meeting": {
    "id": "uuid...",
    "channelName": "test-channel",
    "title": "Test Meeting",
    "token": "006xxx...",
    "expiresAt": "...",
    "joinUrl": "stemforall://..."
  }
}
```

### 2. Probar desde Flutter

1. Compila y ejecuta la app:
   ```bash
   flutter run -d windows
   ```

2. Inicia sesión con un usuario

3. Intenta crear una reunión

4. Verifica en los logs de Railway que se recibió la petición

### 3. Verificar en Supabase

1. Ve a **Database** > **Table Editor**
2. Abre la tabla `meetings`
3. Deberías ver las reuniones creadas

---

## FAQ y Solución de Problemas

### ¿Necesito un servidor de señalización?

**No.** Agora proporciona sus propios servidores de señalización en la nube. Tu backend solo genera tokens de autenticación.

### ¿Cuánto cuesta esto?

- **Supabase**: Gratis hasta 500 MB de DB, 2 GB de ancho de banda
- **Agora**: Gratis primeros 10,000 minutos/mes
- **Railway**: Gratis con límites, ~$5/mes después
- **Render**: Gratis con suspensión después de inactividad

### Error: "CORS policy"

En el backend, actualiza `.env`:
```env
ALLOWED_ORIGINS=https://tu-dominio.com,http://localhost
```

O temporalmente:
```env
ALLOWED_ORIGINS=*
```

### Error: "Token inválido o expirado"

1. Verifica que el JWT de Supabase sea válido
2. Verifica que `SUPABASE_SERVICE_KEY` esté configurado en el backend
3. Verifica que el usuario exista en Supabase

### Error: "No tienes permisos para crear reuniones"

1. Ve a Supabase > Table Editor > `profiles`
2. Busca tu usuario
3. Establece `can_create_meetings = true`

### El backend se duerme en Render/Railway

**Render Free**: Se suspende tras 15 min de inactividad
- **Solución**: Usar un servicio de "pinging" o pagar plan

**Railway**: No se suspende en el plan gratuito

### ¿Cómo actualizo el backend?

```bash
# Edita tus archivos
git add .
git commit -m "Update backend"
git push origin main

# Railway/Render desplegarán automáticamente
```

### ¿Cómo ver logs del backend?

**Railway**: Projects > tu proyecto > Deployments > Ver logs  
**Render**: Dashboard > tu servicio > Logs  
**Heroku**: `heroku logs --tail`

---

## Checklist Final

### Backend
- [ ] Código subido a GitHub
- [ ] Desplegado en Railway/Render/Heroku
- [ ] Variables de entorno configuradas
- [ ] Health check respondiendo
- [ ] URL anotada

### Supabase
- [ ] Proyecto creado
- [ ] Script SQL ejecutado
- [ ] Tablas `meetings` y `meeting_participants` creadas
- [ ] Políticas RLS verificadas
- [ ] Credenciales anotadas

### Agora
- [ ] Proyecto creado
- [ ] Modo "Secured" habilitado
- [ ] App ID y Certificate anotados

### Flutter
- [ ] Dependencia `http` agregada
- [ ] `BACKEND_URL` configurado en `.env`
- [ ] `meeting_service.dart` implementado
- [ ] Certificado de Agora removido del cliente
- [ ] App compilando sin errores

### Pruebas
- [ ] Health check funciona
- [ ] Crear reunión funciona desde curl
- [ ] Crear reunión funciona desde Flutter
- [ ] Unirse a reunión funciona
- [ ] Reuniones se ven en Supabase

---

## Próximos Pasos

1. **Producción**: 
   - Configura un dominio personalizado
   - Habilita HTTPS (Railway lo hace automático)
   - Restringe CORS a tu dominio

2. **Seguridad**:
   - Implementa refresh tokens
   - Agrega rate limiting más estricto
   - Monitorea logs de seguridad

3. **Características**:
   - Notificaciones de reunión
   - Grabación de llamadas (Agora Cloud Recording)
   - Chat en tiempo real mejorado

4. **Monitoreo**:
   - Configura alertas en Railway/Render
   - Monitorea uso de Agora
   - Revisa logs de Supabase

---

## Recursos Adicionales

- [Documentación de Agora](https://docs.agora.io)
- [Documentación de Supabase](https://supabase.com/docs)
- [Railway Docs](https://docs.railway.app)
- [Express.js Guide](https://expressjs.com/guide)

---

**¡Listo!** Ahora tienes un sistema completo de videollamadas con autenticación y tokens seguros. 🎉
