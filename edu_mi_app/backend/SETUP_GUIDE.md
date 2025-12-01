# Configuración del Backend

## 📋 Pasos de Configuración

### 1. Instalar Dependencias del Backend

```bash
cd backend
npm install
```

### 2. Configurar Variables de Entorno

1. Copia `.env.example` a `.env`:
   ```bash
   cp .env.example .env
   ```

2. Completa los valores en `.env`:
   - **SUPABASE_URL**: URL de tu proyecto en Supabase
   - **SUPABASE_SERVICE_KEY**: Service Key (Role Key) desde Settings > API
   - **AGORA_APP_ID**: App ID desde la consola de Agora
   - **AGORA_APP_CERTIFICATE**: Certificate desde la consola de Agora

### 3. Configurar la Base de Datos

1. Abre tu proyecto en Supabase
2. Ve a SQL Editor
3. Ejecuta el script `backend/database/schema.sql`

### 4. Actualizar el Cliente Flutter

1. Agrega la dependencia `http` en `pubspec.yaml`:
   ```yaml
   dependencies:
     http: ^1.1.0
   ```

2. Actualiza la URL del backend en `lib/services/meeting_service.dart`:
   ```dart
   static const String baseUrl = 'https://tu-backend-en-produccion.com/api';
   ```

### 5. Iniciar el Backend

**En desarrollo:**
```bash
cd backend
npm run dev
```

**En producción:**
```bash
cd backend
npm start
```

## 🔄 Flujo de Uso

### Desde Flutter:

1. **Crear Reunión:**
   ```dart
   final meeting = await MeetingService().createMeeting(
     channelName: 'mi-reunion',
     title: 'Mi Reunión',
   );
   // meeting contiene: channelName, token, expiresAt, joinUrl
   ```

2. **Unirse a Reunión:**
   ```dart
   final meeting = await MeetingService().joinMeeting('mi-reunion');
   // meeting contiene el token de Agora
   ```

3. **Listar Reuniones:**
   ```dart
   final meetings = await MeetingService().getActiveMeetings();
   ```

4. **Finalizar Reunión:**
   ```dart
   await MeetingService().endMeeting(meetingId);
   ```

## 🚀 Despliegue en Producción

### Backend

Opciones recomendadas:
1. **Railway** (https://railway.app)
   - Conecta tu repositorio de GitHub
   - Configura las variables de entorno
   - Despliega automáticamente

2. **Render** (https://render.com)
   - Gratis para empezar
   - Despliegue automático desde GitHub

3. **Heroku**
   - Clásico y confiable
   - Requiere tarjeta de crédito

### Frontend Flutter

Actualiza la URL del backend en producción:
```dart
// lib/services/meeting_service.dart
static const String baseUrl = 'https://tu-backend.railway.app/api';
```

## ⚠️ Importante

1. **Nunca** subas el archivo `.env` al repositorio
2. **Siempre** usa HTTPS en producción
3. **Configura** CORS para permitir solo tu dominio en producción
4. **Usa** la Service Key de Supabase solo en el backend, nunca en el cliente
5. **Configura** rate limiting apropiado para producción

## 🔒 Seguridad

- ✅ Tokens JWT verificados en cada petición
- ✅ Service Key de Supabase solo en el backend
- ✅ Certificado de Agora protegido
- ✅ Rate limiting habilitado
- ✅ CORS configurado
- ✅ Helmet para headers de seguridad
- ✅ RLS (Row Level Security) en Supabase

## 🧪 Probar el Backend

```bash
# Health check
curl http://localhost:3000/health

# Crear reunión (reemplaza YOUR_TOKEN)
curl -X POST http://localhost:3000/api/meetings/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SUPABASE_JWT_TOKEN" \
  -d '{"channelName":"test","title":"Test Meeting"}'
```

## 📝 Notas

- El backend maneja la autenticación automáticamente
- Los tokens de Agora se generan en el servidor de forma segura
- Las reuniones expiran automáticamente según la configuración
- Los permisos se verifican antes de cada acción
