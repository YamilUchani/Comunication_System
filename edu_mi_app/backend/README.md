# Backend EduMi App

Backend Node.js para la aplicación EduMi que maneja la autenticación, autorización y generación de tokens de Agora para videollamadas.

## 🚀 Características

- ✅ Autenticación con Supabase JWT
- ✅ Generación segura de tokens de Agora
- ✅ Verificación de permisos de usuario
- ✅ Gestión de reuniones (crear, unirse, listar, finalizar)
- ✅ Rate limiting para prevenir abuso
- ✅ CORS configurado
- ✅ Seguridad con Helmet
- ✅ Validación de datos

## 📋 Requisitos Previos

- Node.js >= 18.0.0
- Cuenta de Supabase
- Cuenta de Agora con App ID y Certificate

## 🛠️ Instalación

### 1. Instalar dependencias

```bash
cd backend
npm install
```

### 2. Configurar variables de entorno

Copia el archivo `.env.example` a `.env` y completa los valores:

```bash
cp .env.example .env
```

Edita `.env` con tus credenciales:

```env
PORT=3000
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_SERVICE_KEY=tu_service_key
AGORA_APP_ID=tu_app_id
AGORA_APP_CERTIFICATE=tu_certificado
```

### 3. Configurar la base de datos

Ejecuta el script SQL en Supabase:

1. Ve a tu proyecto en Supabase
2. Abre el SQL Editor
3. Ejecuta el contenido de `database/schema.sql`

### 4. Iniciar el servidor

**Modo desarrollo (con auto-reload):**
```bash
npm run dev
```

**Modo producción:**
```bash
npm start
```

El servidor estará corriendo en `http://localhost:3000`

## 📡 API Endpoints

### Autenticación

Todos los endpoints requieren un token JWT de Supabase en el header:
```
Authorization: Bearer <tu_token_jwt>
```

### Endpoints Disponibles

#### 1. Crear Reunión
```http
POST /api/meetings/create
Content-Type: application/json
Authorization: Bearer <token>

{
  "channelName": "mi-reunion-123",
  "title": "Reunión de Matemáticas",
  "description": "Clase de geometría"
}
```

**Respuesta:**
```json
{
  "meeting": {
    "id": "uuid",
    "channelName": "mi-reunion-123",
    "title": "Reunión de Matemáticas",
    "description": "Clase de geometría",
    "token": "token_de_agora_generado",
    "expiresAt": "2024-01-01T12:00:00Z",
    "joinUrl": "stemforall://meeting?channel=mi-reunion-123&token=..."
  }
}
```

#### 2. Unirse a Reunión
```http
POST /api/meetings/join
Content-Type: application/json
Authorization: Bearer <token>

{
  "channelName": "mi-reunion-123"
}
```

**Respuesta:**
```json
{
  "meeting": {
    "id": "uuid",
    "channelName": "mi-reunion-123",
    "title": "Reunión de Matemáticas",
    "description": "Clase de geometría",
    "token": "token_de_agora_generado",
    "expiresAt": "2024-01-01T12:00:00Z"
  }
}
```

#### 3. Listar Reuniones Activas
```http
GET /api/meetings/active
Authorization: Bearer <token>
```

**Respuesta:**
```json
{
  "meetings": [
    {
      "id": "uuid",
      "channelName": "mi-reunion-123",
      "title": "Reunión de Matemáticas",
      "description": "Clase de geometría",
      "creatorName": "Juan Pérez",
      "creatorAvatar": "https://...",
      "createdAt": "2024-01-01T11:00:00Z",
      "expiresAt": "2024-01-01T12:00:00Z"
    }
  ]
}
```

#### 4. Finalizar Reunión
```http
POST /api/meetings/:meetingId/end
Authorization: Bearer <token>
```

**Respuesta:**
```json
{
  "message": "Reunión finalizada exitosamente"
}
```

#### 5. Health Check
```http
GET /health
```

**Respuesta:**
```json
{
  "status": "OK",
  "timestamp": "2024-01-01T12:00:00Z",
  "environment": "development"
}
```

## 🔒 Seguridad

### Middleware de Autenticación

El middleware `authenticateUser` verifica que:
- El token JWT sea válido
- El usuario exista en Supabase
- El perfil del usuario esté completo

### Middleware de Permisos

El middleware `canCreateMeeting` verifica que:
- El usuario tenga permiso para crear reuniones (`can_create_meetings`)
- No haya excedido el límite de reuniones activas (`meeting_limit`)

### Rate Limiting

Por defecto:
- **Ventana:** 15 minutos
- **Límite:** 100 peticiones por IP

## 🗂️ Estructura del Proyecto

```
backend/
├── config/
│   └── supabase.js          # Cliente de Supabase
├── middleware/
│   └── auth.js              # Autenticación y autorización
├── routes/
│   └── meetings.js          # Rutas de reuniones
├── services/
│   └── agoraToken.js        # Generación de tokens de Agora
├── database/
│   └── schema.sql           # Esquema de la base de datos
├── .env.example             # Plantilla de variables de entorno
├── server.js                # Punto de entrada
└── package.json             # Dependencias
```

## 🧪 Pruebas con cURL

### Crear una reunión
```bash
curl -X POST http://localhost:3000/api/meetings/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"channelName":"test-meeting","title":"Test Meeting"}'
```

### Listar reuniones activas
```bash
curl http://localhost:3000/api/meetings/active \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## 🔧 Configuración Avanzada

### CORS

Para permitir múltiples orígenes, edita `.env`:
```env
ALLOWED_ORIGINS=http://localhost:3000,https://tu-dominio.com,http://192.168.1.100:3000
```

### Expiración de Tokens

Para cambiar el tiempo de expiración de los tokens de Agora (en segundos):
```env
TOKEN_EXPIRATION_TIME=7200  # 2 horas
```

## 📊 Monitoreo

El servidor incluye logs detallados para:
- Peticiones HTTP
- Errores de autenticación
- Creación y finalización de reuniones
- Errores de la base de datos

## 🚢 Despliegue

### Opciones recomendadas:
1. **Railway** - Despliegue fácil con GitHub
2. **Heroku** - Clásico y confiable
3. **DigitalOcean App Platform** - Escalable
4. **Render** - Gratis con limitaciones

### Variables de entorno necesarias en producción:
- `PORT` (usualmente asignado automáticamente)
- `NODE_ENV=production`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_KEY`
- `AGORA_APP_ID`
- `AGORA_APP_CERTIFICATE`
- `ALLOWED_ORIGINS`

## 🐛 Solución de Problemas

### Error: "Token de autenticación no proporcionado"
- Verifica que estés enviando el header `Authorization: Bearer <token>`
- El token debe ser un JWT válido de Supabase

### Error: "No tienes permisos para crear reuniones"
- Verifica el campo `can_create_meetings` en tu perfil de Supabase
- Por defecto debería ser `true`

### Error: "Ya existe una reunión activa con ese nombre de canal"
- Usa un nombre de canal diferente
- O finaliza la reunión anterior primero

## 📝 Licencia

MIT
