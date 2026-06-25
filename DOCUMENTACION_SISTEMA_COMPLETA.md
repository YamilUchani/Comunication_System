# 📚 DOCUMENTACIÓN COMPLETA DEL SISTEMA
## "De Supervisor a Co-Aprendiz" — Ecosistema Educativo

---

## 📋 ÍNDICE

1. [Visión General del Sistema](#visión-general-del-sistema)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [App_Supervisor (Panel Web para Padres)](#app_supervisor)
4. [edu_mi_app (App Flutter Desktop)](#edu_mi_app)
5. [Backend y Servicios](#backend-y-servicios)
6. [Base de Datos](#base-de-datos)
7. [Configuración y Despliegue](#configuración-y-despliegue)

---

## 🎯 VISIÓN GENERAL DEL SISTEMA

**De Supervisor a Co-Aprendiz** es un ecosistema educativo completo que conecta a padres, estudiantes y maestros en una plataforma unificada de aprendizaje virtual.

### Componentes Principales:
- **App_Supervisor**: Panel web para padres (HTML/CSS/JS vanilla)
- **edu_mi_app**: Aplicación de escritorio Flutter para estudiantes y maestros
- **Backend Express**: API REST con motor de reglas y lógica de negocio
- **Supabase**: Base de datos PostgreSQL con autenticación y tiempo real
- **Firebase**: Hosting y funciones serverless
- **Agora**: Motor de videoconferencias WebRTC

### Flujo de Usuario:
```
Padre → App_Supervisor (Web) → Ve progreso, asistencia, logros
Estudiante/Maestro → edu_mi_app (Desktop) → Clases virtuales, materiales
Sistema → Backend → Evalúa reglas, genera alertas, procesa pagos
```

---

## 🏗️ ARQUITECTURA DEL SISTEMA

```
┌─────────────────────────────────────────────────────────┐
│                    CAPA DE PRESENTACIÓN                  │
├─────────────────────┬───────────────────────────────────┤
│  App_Supervisor     │  edu_mi_app (Flutter Desktop)    │
│  (HTML/CSS/JS)      │  Windows/Mac/Linux               │
│  - Panel Padres     │  - Dashboard Estudiantes         │
│  - Login/Registro   │  - Dashboard Maestros            │
│  - OAuth Google     │  - Videollamadas Agora           │
└─────────────────────┴───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    CAPA DE API/BACKEND                   │
├─────────────────────┬───────────────────────────────────┤
│  Express Server     │  Firebase Functions               │
│  (Render/Railway)   │  (Hosting + Cloud Functions)      │
│  - Rules Engine     │  - OAuth Callback                 │
│  - Payment Gateway  │  - Notificaciones Push            │
│  - Meetings CRUD     │                                   │
└─────────────────────┴───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    CAPA DE DATOS                         │
├─────────────────────┬───────────────────────────────────┤
│  Supabase Cloud     │  Base de Datos PostgreSQL         │
│  - Auth             │  - Tablas relacionales            │
│  - Realtime         │  - RLS (Row Level Security)       │
│  - Storage          │  - Triggers y Functions            │
└─────────────────────┴───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                 SERVICIOS EXTERNOS                       │
├─────────────────────┬───────────────────────────────────┤
│  Agora.io           │  Google OAuth 2.0                 │
│  - Video/Audio      │  - Autenticación Social           │
│  - Screen Share     │  - Tokens JWT                     │
│  - Chat RTM         │                                   │
└─────────────────────┴───────────────────────────────────┘
```

---

## 🌐 APP_SUPERVISOR (Panel Web para Padres)

**Ruta base**: `App_Supervisor/`

### 📄 Archivos Principales

---

#### **1. `index.html`** — Página de Login/Registro

**Propósito**: Punto de entrada principal para autenticación de padres.

**Funcionalidad**:
- Diseño de dos paneles (izquierdo: branding, derecho: formulario)
- Tabs para alternar entre "Entrar" y "Registrarse"
- Formulario de login con email/contraseña
- Formulario de registro con nombre/email/contraseña
- Botón de autenticación con Google OAuth 2.0
- Indicador de estado de conexión (Supabase Cloud vs Local Fallback)
- Overlay de carga mientras verifica sesión existente
- Validación de campos y traducción de errores
- Responsive design (se oculta panel izquierdo en móviles <900px)

**Características Técnicas**:
- CSS Grid para layout de dos columnas
- Variables CSS customizadas para tema oscuro
- Animaciones de entrada (fadeInUp)
- Google Fonts: Inter + Outfit
- SDK de Supabase v2 cargado desde CDN
- Manejo de OAuth implícito (hash fragment)

**Flujo de Autenticación**:
```
1. Usuario ingresa credenciales
2. Si Supabase está activo → signInWithPassword() o signUp()
3. Si es Google → signInWithOAuth(provider: 'google')
4. Éxito → redirige a app.html
5. Fallo → muestra error traducido
```

---

#### **2. `app.html`** — Dashboard Principal del Padre

**Propósito**: Panel de control post-autenticación para supervisión educativa.

**Funcionalidad**:
- **Header**: Logo, selector de estudiante, badge de conexión, perfil de usuario, botón logout
- **Sidebar**: Navegación entre 7 secciones:
  1. Resumen General (Dashboard)
  2. Registro de Asistencia
  3. Progreso de Niveles
  4. Logros Obtenidos
  5. Horarios de Clase
  6. Materiales Asignados
  7. Reuniones y Clases Virtuales
- **KPI Cards**: 4 métricas principales (Nivel Activo, Clases Asistidas, Logros, Fichas Completadas)
- **Perfil del Estudiante**: Nombre, grupo, email, barra de progreso global
- **Telemetry Console**: Consola de debugging desplegable en la parte inferior

**Características Técnicas**:
- CSS Grid para layout principal (header + sidebar + main)
- Sistema de tabs con animaciones fadeIn
- Selector dinámico de estudiantes (dropdown)
- Barra de progreso animada con gradientes
- Consola de telemetría con logs en tiempo real
- Integración con Supabase para datos en tiempo real
- Fallback a datos mock si no hay conexión

**Secciones del Dashboard**:

1. **Resumen General**:
   - 4 KPI cards con iconos SVG
   - Información del estudiante (nombre, grupo, email)
   - Barra de progreso de niveles (X/Y - Z%)

2. **Registro de Asistencia**:
   - Lista de sesiones asistidas
   - Fecha, duración, estado (Puntual/Tardanza)
   - Horarios de conexión y desconexión

3. **Progreso de Niveles**:
   - Lista de retos de aprendizaje
   - Estado: Superado/Pendiente
   - Fecha de finalización
   - Descripción del reto

4. **Logros Obtenidos**:
   - Agrupados por fecha
   - Icono, nombre, descripción
   - Puntos XP ganados
   - Ordenados cronológicamente (más reciente primero)

5. **Horarios de Clase**:
   - Día de la semana, materia, profesor
   - Horario de inicio y fin
   - Estado: Activo

6. **Materiales Asignados**:
   - Título y descripción
   - Estado: Completado/Pendiente
   - Link de descarga PDF (si existe)

7. **Reuniones y Clases Virtuales**:
   - Título, descripción
   - Canal Agora
   - Tipo de reunión
   - Estado: En Vivo

---

#### **3. `css/styles.css`** — Sistema de Diseño Completo

**Propósito**: Hoja de estilos principal con design system completo.

**Design Tokens** (Variables CSS):
```css
--bg-primary: #0f172a (fondo principal)
--bg-secondary: #1e293b (tarjetas)
--border-color: rgba(255,255,255,0.12)
--accent-primary: #6366f1 (índigo)
--accent-secondary: #10b981 (verde)
--accent-colearn: #8b5cf6 (violeta)
--text-primary: #f9fafb
--text-secondary: #9ca3af
--text-muted: #6b7280
--font-title: 'Outfit' (títulos)
--font-body: 'Inter' (cuerpo)
--radius-sm/md/lg: 8/12/20px
```

**Componentes CSS**:
- **Header**: Backdrop blur, sticky, z-index 100
- **Sidebar**: Navegación vertical con hover effects, active states con borde izquierdo
- **KPI Cards**: Grid responsive, hover con elevación, barras de color superior
- **Grade Rows**: Filas de lista con hover, badges de estado (pills)
- **Telemetry Drawer**: Panel fijo inferior, expandible, estilo terminal
- **Login Modal**: Overlay con blur, card centrada, tabs de auth
- **Responsive**: Media queries a 900px y 600px

**Animaciones**:
- `fadeIn`: Entrada de tabs
- `slideDown`: Entrada desde arriba
- `pulse`: Indicador de conexión
- `spin`: Spinner de carga

---

#### **4. `js/app-supervisor-config.js`** — Configuración de la App

**Propósito**: Centralizar credenciales y configuración de Supabase.

**Contenido**:
```javascript
window.APP_SUPERVISOR_CONFIG = {
  supabaseUrl: "https://tcbmlktpzshltvmoirjs.supabase.co",
  supabaseAnonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  appUrl: "https://educoparent-callback.web.app"
}
```

**Uso**:
- `supabaseUrl`: URL del proyecto Supabase compartido con edu_mi_app
- `supabaseAnonKey`: Clave pública anónima (segura para frontend)
- `appUrl`: URL de callback OAuth para Google (Firebase Hosting)

**Nota**: Esta configuración es compartida entre App_Supervisor y edu_mi_app, pero cada uno tiene su propio archivo de configuración para aislar las URLs de retorno OAuth.

---

#### **5. `js/supabase-config.js`** — Cliente Supabase y API Wrapper

**Propósito**: Inicializar cliente Supabase y exponer métodos de autenticación y datos.

**Estructura**:

**A. Inicialización**:
- Lee configuración desde `APP_SUPERVISOR_CONFIG`
- Valida URL con regex `https://[a-z0-9-]+\.supabase\.co`
- Crea cliente Supabase con `createClient()`
- Manejo de errores con try-catch
- Estado `isSupabaseActive` para fallback

**B. `supabaseAuth` (Autenticación)**:
- `signUp(email, password, fullName)`: Registro + creación de perfil parent
- `signInWithGoogle()`: OAuth con Google, redirect a `appUrl`
- `signIn(email, password)`: Login con credenciales
- `signOut()`: Cierre de sesión
- `getSession()`: Obtener sesión actual
- `onAuthChange(callback)`: Listener de cambios de auth
- `getCurrentUser()`: Obtener usuario actual
- `setSession(accessToken, refreshToken)`: Restaurar sesión desde tokens

**C. `supabaseApi` (Datos)**:
- `isActive()`: Verificar si Supabase está conectado
- `getMyStudents()`: Obtener estudiantes vinculados al padre (via `parent_students`)
- `getStudents()`: Obtener todos los estudiantes (fallback)
- `getAttendance(studentId)`: Registro de asistencia
- `getLevelProgress(studentId)`: Progreso de niveles (join con `challenges`)
- `getAchievements(studentId)`: Logros desbloqueados (join con `achievements`)
- `getClassSchedules(groupName)`: Horarios de clase por grupo
- `getMaterialProgress(studentId)`: Materiales asignados (join con `materials`)
- `getMeetings(studentId)`: Reuniones virtuales activas
- `upsertParentProfile(profileData)`: Crear/actualizar perfil de padre

**Patrón de Fallback**:
```javascript
if (isSupabaseActive) {
  // Intentar consulta real a Supabase
  const { data, error } = await supabaseClient.from('tabla').select('*');
  if (error) throw error;
  return data;
} else {
  // Fallback a datos mock locales
  return window.mockDb.tabla.filter(...);
}
```

---

#### **6. `js/app.js`** — Lógica Principal de la Aplicación

**Propósito**: Controlador principal del dashboard, manejo de estado y renderizado.

**Variables de Estado**:
- `currentStudentId`: ID del estudiante seleccionado
- `currentStudent`: Objeto completo del estudiante
- `currentTab`: Tab activo en sidebar
- `loadedStudents`: Array de estudiantes disponibles

**Funciones Principales**:

**A. Inicialización (`init`)**:
1. Actualizar badge de conexión
2. Vincular eventos de navegación
3. Escuchar cambios de autenticación (logout automático)
4. Verificar sesión existente
5. Si no hay sesión → modo local con datos mock
6. Cargar datos del estudiante

**B. Gestión de Estudiantes (`loadStudents`)**:
1. Intentar `getMyStudents()` (vinculados al padre)
2. Si falla o está vacío → `getStudents()` (todos)
3. Si no hay datos → `mockDb.profiles`
4. Mapear a formato estándar: `{id, name, grade, email, avatar_url, ...}`
5. Poblar dropdown selector
6. Seleccionar primer estudiante por defecto
7. Llamar `loadStudentData()`

**C. Carga de Datos (`loadStudentData`)**:
- Ejecuta 6 consultas en paralelo con `Promise.allSettled`:
  1. Asistencia
  2. Progreso de niveles
  3. Logros
  4. Horarios
  5. Materiales
  6. Reuniones
- Calcula KPIs: nivel activo, total clases, logros, materiales completados
- Calcula porcentaje de progreso global
- Renderiza cada sección con funciones específicas

**D. Renderizado de Listas**:
- `renderAttendanceList()`: Cards con fecha, duración, puntualidad
- `renderLevelsList()`: Retos con estado Superado/Pendiente
- `renderAchievementsList()`: Agrupados por fecha, con iconos y XP
- `renderSchedulesList()`: Horarios con día, materia, profesor
- `renderMaterialsList()`: Materiales con link de descarga PDF
- `renderMeetingsList()`: Reuniones con canal Agora

**E. Telemetría (`logTelemetry`)**:
- Logs en consola y en UI (drawer inferior)
- Categorías: SYSTEM, AUTH, SUPABASE, SUPABASE_ERROR, STUDENTS, NAVIGATION, ACTION
- Timestamp automático
- Colores por tipo: error=rojo, warn=amarillo, info=azul

**F. Eventos**:
- Cambio de estudiante en dropdown → recargar datos
- Click en nav items → cambiar tab
- Click en telemetry header → expandir/colapsar drawer
- Logout → cerrar sesión y redirigir a login

---

#### **7. `js/data.js`** — Base de Datos Mock (Local Fallback)

**Propósito**: Datos simulados idénticos al schema de Supabase para desarrollo sin conexión.

**Tablas Mock**:

1. **profiles** (3 estudiantes):
   - Damian Agramont Pareja (8A, nivel 8)
   - Angel Andre Calle Mansmith (8B, nivel 12)
   - Bernard Alejandro Ibañez (8A, nivel 15)

2. **attendance** (2 registros):
   - Sesión 2025-06-15: Puntual, 90 min
   - Sesión 2025-06-16: Tardanza, 85 min

3. **student_level_progress** (2 retos):
   - ch-001: Introducción a Programación (completado)
   - ch-002: Variables y Tipos de Datos (en progreso)

4. **challenges** (2 retos):
   - Introducción a la Programación
   - Variables y Tipos de Datos

5. **student_achievements** (2 logros):
   - Primer Paso (100 XP)
   - Estudiante Dedicado (250 XP)

6. **achievements** (2 logros):
   - Primer Paso 🥇
   - Estudiante Dedicado ⭐

7. **class_schedules** (2 horarios):
   - Programación Básica: Lunes 10:00-11:30
   - Matemáticas: Miércoles 08:00-09:30

8. **student_material_progress** (2 materiales):
   - Ficha Variables: Completado
   - Guía Bucles: Pendiente

9. **materials** (2 materiales):
   - Ficha de Refuerzo - Variables (PDF)
   - Guía de Estudio - Bucles (PDF)

10. **meetings** (2 reuniones):
    - Clase de Introducción (canal: edu-8a-programacion-001)
    - Repaso de Variables (canal: edu-8a-variables-001)

**Uso**: Se accede via `window.mockDb.nombreTabla`

---

#### **8. `server/server.js`** — Backend Express (Render)

**Propósito**: API REST con motor de reglas y pasarela de pagos.

**Dependencias**:
- `express`: Framework web
- `cors`: Middleware CORS
- `@supabase/supabase-js`: Cliente Supabase
- `dotenv`: Variables de entorno

**Endpoints**:

1. **`GET /api/health`**:
   - Health check del servidor
   - Retorna: status, timestamp, supabaseConnected, environment, port, serving

2. **`POST /api/rules-engine/evaluate`**:
   - **Propósito**: Motor de reglas para alertas automatizadas
   - **Input**: `{studentId, studentName, grades: [{subject, score, category, teacher_id}]}`
   - **Lógica**: Si alguna nota < 70 → generar alerta
   - **Acción**: Insertar en tabla `alerts` con tipo 'warning', acción 'schedule_meeting'
   - **Output**: `{alertTriggered, alert: {type, message, action, teacherId, comments}, dbStatus}`
   - **dbStatus**: "inserted_to_supabase", "mocked", "failed_db_fallback_local"

3. **`POST /api/payment/charge`**:
   - **Propósito**: Simulación de pasarela de pagos PCI DSS compliant
   - **Input**: `{cardToken, amount, courseTitle, familyProfileId}`
   - **Validación**: Token debe empezar con "tok_stripe_" (tokenización)
   - **Seguridad**: Rechaza datos de tarjeta directos (PCI DSS)
   - **Output**: `{success, transactionId, amount, status, tokenUsed, date, receiptUrl}`

4. **`GET *` (SPA Fallback)**:
   - Sirve `app.html` para rutas no-API
   - Permite routing del lado cliente

**Variables de Entorno**:
- `PORT`: Puerto del servidor (default: 8000)
- `SUPABASE_URL`: URL de Supabase
- `SUPABASE_ANON_KEY`: Clave anónima de Supabase
- `NODE_ENV`: Entorno (development/production)

**Modo Fallback**: Si no hay variables de Supabase, el servidor corre en "Local Mock Mode" y las operaciones de BD retornan datos simulados.

---

#### **9. `server/package.json`** — Dependencias del Backend

**Dependencias**:
- `@supabase/supabase-js`: ^2.39.0
- `cors`: ^2.8.5
- `dotenv`: ^16.3.1
- `express`: ^4.18.2

**Scripts**:
- `npm start`: Inicia servidor en producción
- `npm run dev`: Inicia con nodemon (auto-reload)

**Engines**: Node >=14.0.0

---

### 🔥 Firebase Hosting (OAuth Callback)

#### **10. `firebase/.firebaserc`** — Configuración de Proyecto Firebase

**Propósito**: Vincular carpeta `firebase/` al proyecto Firebase.

**Contenido**:
```json
{
  "projects": {
    "default": "stemforall-f57ac"
  }
}
```

**Proyecto**: `stemforall-f57ac` (proyecto Firebase de STEM for All)

---

#### **11. `firebase/firebase.json`** — Configuración de Hosting

**Propósito**: Definir reglas de despliegue en Firebase Hosting.

**Configuración**:
- **site**: `educoparent-callback` (subdominio de Firebase)
- **public**: `public/` (carpeta de archivos estáticos)
- **ignore**: Archivos a excluir del deploy
- **headers**: Cache-Control `no-cache, no-store, must-revalidate` (para OAuth)
- **rewrites**: Todas las rutas → `/index.html` (SPA)

**URL Final**: `https://educoparent-callback.web.app`

---

#### **12. `firebase/public/index.html`** — Página de Callback OAuth

**Propósito**: Procesar tokens de autenticación OAuth de Google/Supabase.

**Flujo**:
```
1. Usuario autentica con Google en App_Supervisor
2. Supabase redirige a esta página con tokens en URL
3. Página extrae access_token y refresh_token
4. Construye deep link: stemforall://auth-callback?access_token=...&refresh_token=...
5. Redirige automáticamente a la app de escritorio
6. La app captura el deep link y completa la sesión
```

**Estados de UI**:
- **Loading**: Spinner + "Procesando autenticación..."
- **Success**: Checkmark + "Abriendo EduCoParent..." + botón manual
- **Error**: Mensaje de error + botón de retry

**Características**:
- Modo debug activado (`DEBUG_MODE = true`)
- Panel de debug muestra tokens y parámetros
- Limpia URL después de procesar (`history.replaceState`)
- Timeout de 1.5s antes de redirigir
- Botón de respaldo si la redirección automática falla

---

#### **13. `firebase/DEPLOY_HOSTING.md`** — Guía de Despliegue

**Propósito**: Instrucciones paso a paso para desplegar el callback OAuth.

**Contenido**:
- Inicialización de Firebase Hosting
- Configuración de Redirect URLs en Supabase
- Configuración de OAuth en Google Cloud Console
- Actualización de `appUrl` en configuración
- Comandos de deploy (`firebase deploy --only hosting`)
- Verificación del despliegue
- Flujo completo de autenticación (diagrama)
- Pruebas locales (`firebase serve --only hosting`)
- Debugging y FAQ

---

### 🗄️ Base de Datos Supabase

#### **14. `supabase/schema.sql`** — Schema de Base de Datos

**Propósito**: Definir estructura de tablas y políticas de seguridad.

**Tablas**:

1. **profiles**:
   - `id` (UUID, PK, referencia a auth.users)
   - `email`, `full_name`, `created_at`
   - RLS: Usuarios pueden leer/actualizar su propio perfil

2. **students**:
   - `id`, `parent_id` (FK a profiles), `name`, `grade_level`
   - `avatar_code`, `avatar_color`, `gpa`, `attendance`
   - RLS: Padres ven solo sus estudiantes

3. **teachers**:
   - `id`, `name`, `subject`, `email`, `color`
   - RLS: Lectura pública

4. **grades**:
   - `id`, `student_id` (FK), `subject`, `score`, `max_score`
   - `date`, `category`, `teacher_id` (FK), `comments`
   - RLS: Padres ven notas de sus estudiantes

5. **tasks**:
   - `id`, `student_id` (FK), `title`, `subject`, `due_date`
   - `status`, `difficulty`, `resources` (JSONB), `discussions` (JSONB)
   - RLS: Padres leen tareas, pueden actualizar discussions

6. **chats**:
   - `id`, `sender_id`, `receiver_id`, `text`, `timestamp`
   - RLS: Usuarios leen sus propios chats, pueden enviar como sender

7. **calendar_events**:
   - `id`, `parent_id` (FK), `title`, `type`, `event_date`, `event_time`, `note`
   - RLS: Padres CRUD completo en sus eventos

8. **alerts**:
   - `id`, `student_id` (FK), `type`, `message`, `action`
   - `teacher_id` (FK), `resolved`, `created_at`
   - RLS: Padres leen/actualizan alertas de sus estudiantes

**Características**:
- Todas las tablas tienen `created_at` automático
- Foreign Keys con `ON DELETE CASCADE` o `SET NULL`
- Row Level Security (RLS) habilitado en todas las tablas
- Políticas granulares por rol (parent, student, teacher)

---

#### **15. `supabase/parent_students.sql`** — Tabla de Vinculación

**Propósito**: Relación muchos-a-muchos entre padres y estudiantes.

**Estructura**:
- `id` (UUID, PK)
- `parent_id` (UUID, FK a auth.users)
- `student_id` (UUID, FK a auth.users)
- `created_at`
- Unique constraint: `(parent_id, student_id)`
- Índices en ambas columnas para queries rápidas

**RLS**: Padres pueden ver solo sus propios vínculos.

**Uso**:
- Un padre puede tener múltiples estudiantes (hijos)
- Un estudiante puede estar vinculado a múltiples padres (tutor legal, etc.)
- Consulta desde App_Supervisor: `getMyStudents()`

**Métodos de Vinculación**:
1. **Panel Admin**: Interfaz gráfica en edu_mi_app
2. **SQL Manual**: INSERT directo con UUIDs

---

#### **16. `INSTRUCCIONES_DETALLADAS.md`** — Guía de Configuración

**Propósito**: Documento maestro de setup del sistema completo.

**Contenido**:
- Arquitectura del sistema (diagrama)
- Paso 1: Configuración de Supabase (schema, RLS, API keys)
- Paso 2: Despliegue en Render (backend Express)
- Paso 3: Configuración de Firebase (Auth, Hosting)
- Mecanismo de Fallback Inteligente (Local vs Cloud)

**Modo Fallback**:
- Sin credenciales → Indicador "LOCAL FALLBACK", datos mock desde `data.js`
- Con credenciales → Indicador "CONECTADO A SUPABASE CLOUD", datos reales

---

## 📱 EDU_MI_APP (App Flutter Desktop)

**Ruta base**: `edu_mi_app/`

### 📄 Archivos Principales

---

#### **1. `pubspec.yaml`** — Configuración y Dependencias

**Propósito**: Definir metadata, dependencias y assets del proyecto Flutter.

**Información del Proyecto**:
- Nombre: `edu_mi_app`
- Versión: 1.0.0+1
- SDK: Dart ^3.8.1

**Dependencias Principales**:

**Backend/API**:
- `supabase_flutter`: ^2.9.1 (Cliente Supabase para Flutter)
- `flutter_dotenv`: ^5.2.1 (Variables de entorno)
- `http`: ^1.6.0 (Peticiones HTTP)

**Estado/UI**:
- `flutter_riverpod`: ^2.5.1 (Gestión de estado)
- `provider`: ^6.0.5 (Provider pattern)

**Videollamadas**:
- `agora_rtc_engine`: ^6.5.2 (Motor de video/audio Agora)
- `agora_rtm`: ^2.2.2 (Mensajería en tiempo real Agora)

**UI/UX**:
- `table_calendar`: ^3.0.9 (Calendario interactivo)
- `flutter_pdfview`: ^1.4.4 (Visor PDF)
- `syncfusion_flutter_pdfviewer`: ^23.1.39 (Visor PDF avanzado)

**Desktop (Windows)**:
- `window_manager`: ^0.3.7 (Control de ventanas)
- `win32`: ^5.0.0 (APIs nativas de Windows)
- `ffi`: ^2.0.0 (Foreign Function Interface)

**Utilidades**:
- `permission_handler`: ^11.3.1 (Permisos del sistema)
- `flutter_keyboard_visibility`: ^5.3.0 (Detección de teclado)
- `uuid`: ^3.0.7 (Generación de UUIDs)
- `file_picker`: ^10.3.10 (Selector de archivos)
- `url_launcher`: ^6.3.2 (Abrir URLs externas)
- `path_provider`: ^2.1.5 (Rutas del sistema)

**Dev Dependencies**:
- `flutter_test`: SDK de testing
- `flutter_lints`: ^5.0.0 (Linting)

**Assets**:
- `.env` (archivo de variables de entorno)

---

#### **2. `lib/main.dart`** — Punto de Entrada de la App

**Propósito**: Inicializar la aplicación Flutter y gestionar ventanas.

**Flujo de Inicio**:

**A. Inicialización**:
1. Cargar variables de entorno desde `.env`
2. Inicializar Supabase con URL y anon key
3. Configurar `AuthFlowType.implicit` (OAuth implícito)

**B. Lógica de Ventanas Secundarias**:
- Detecta argumento `--secondary` en línea de comandos
- Modos soportados:
  - `video-call`: Ventana de videollamada
  - `waiting-room`: Sala de espera previa a clase
  - `whiteboard`: Pizarra colaborativa global
  - `pdf-viewer`: Visor de PDFs
- Registra PID en archivo temporal para gestión de procesos
- Restaura sesión de Supabase desde refresh token
- Configura ventana (tamaño, posición, always-on-top)

**C. Ventana Principal**:
- `ensureSingleInstance()`: Garantiza una sola instancia (Windows named pipes)
- `DeepLinkService`: Manejo de deep links para OAuth
- `onAuthStateChange`: Navegación automática post-login
- `_nextRoute()`: Determina ruta según rol y perfil:
  - Sin perfil → `/complete-profile`
  - Sin grupo → `/waiting-for-assignment`
  - Admin → `/admin-dashboard`
  - Teacher → `/teacher-dashboard`
  - Student → `/student-dashboard`

**D. Gestión de Cierre**:
- `didRequestAppExit()`: Cierra ventanas secundarias al salir
- `onWindowClose()`: 
  - Si hay videollamada activa → BLOQUEAR cierre
  - Si no → Cerrar inmediatamente

**E. Rutas**:
- `/login` → LoginScreen
- `/register` → RegisterScreen
- `/verify_email` → VerifyEmailScreen
- `/home` → HomeScreen
- `/admin-dashboard` → AdminDashboard
- `/teacher-dashboard` → TeacherDashboard
- `/student-dashboard` → StudentDashboard
- `/complete-profile` → CompleteProfileScreen
- `/waiting-for-assignment` → WaitingForAssignmentScreen
- `/video-call` → ChannelInputScreen

---

#### **3. `lib/screens/login_screen.dart`** — Pantalla de Login

**Propósito**: Autenticación de usuarios (estudiantes, maestros, administradores).

**Campos**:
- Email (TextField)
- Contraseña (TextField, obscureText)
- Botón "Iniciar sesión"
- Botón "Reenviar correo de verificación" (condicional)
- Link "¿Olvidaste tu contraseña?"
- Link "Registrarse"
- Botón "Continuar con Google"

**Lógica**:

**A. Login con Email/Password**:
1. Validar campos no vacíos
2. Llamar `signInWithPassword(email, password)`
3. Actualizar `is_verified` a `true` si es `false`
4. Navegación automática por `onAuthStateChange`

**B. Reenvío de Verificación**:
1. Llamar `resend(type: OtpType.signup, email)`
2. Mostrar SnackBar de confirmación

**C. Recuperación de Contraseña**:
1. Llamar `resetPasswordForEmail(email)`
2. Mostrar SnackBar de confirmación

**D. Login con Google**:
1. Llamar `signInWithOAuth(OAuthProvider.google, redirectTo)`
2. Redirect a `https://stemforall-f57ac.web.app`
3. Procesamiento en `DeepLinkService`

**Manejo de Errores**:
- `Email not confirmed` → Mostrar botón de reenvío
- Otros errores → SnackBar con mensaje traducido

---

#### **4. `lib/screens/student_dashboard.dart`** — Dashboard del Estudiante

**Propósito**: Panel principal para estudiantes con clases, asistencia y logros.

**Secciones**:

**A. AppBar**:
- Título: "Mi Aula"
- Botones: Calendario, Perfil, Refresh, Logout

**B. Espacio de Material**:
- Card con acceso a materiales armables y recursos
- Navegación a `MaterialsScreen`

**C. Estado de Hoy**:
- Card con gradiente (azul si asistió, gris si no)
- Icono de check o schedule
- Texto: "¡Asistencia registrada!" o "Aún no asistes"
- Logros obtenidos hoy (chips con icono y nombre)

**D. Clases Activas**:
- Lista de reuniones en curso
- Card con:
  - Icono (grupo o magistral)
  - Título, descripción
  - Profesor
  - Badge "En curso ahora"
  - Botón "Entrar a Clase"
- Colores: Azul (magistral), Naranja (grupal)

**E. Horario Semanal**:
- Agrupado por día de la semana
- Lista de clases por día
- Materia y horario

**Funcionalidades Especiales**:

**Calendario de Asistencia**:
- Dialog con `TableCalendar`
- Marcadores naranjas en días con asistencia
- Al seleccionar día → mostrar detalle:
  - Estado: "✅ Presente"
  - Logros obtenidos en esa sesión (chips)

**Perfil del Estudiante**:
- Avatar grande
- Historial de asistencia (lista con fechas)
- Todos los logros (lista con iconos, nombres, fechas)

**Unirse a Reunión**:
- Si es privada/grupal → Apertura directa de videollamada
- Si es magistral → Apertura de sala de espera primero

---

#### **5. `lib/services/api_service.dart`** — Servicio de API

**Propósito**: Cliente HTTP para comunicarse con el backend Express.

**Configuración**:
- `_baseUrl`: Leído de `BACKEND_URL` en `.env`
- `_getHeaders()`: Authorization Bearer token de Supabase

**Endpoints Implementados**:

**A. Admin**:
- `getAdminStats()`: Estadísticas generales
- `getUsers({role, search})`: Lista de usuarios
- `updateUserRole(userId, role, groupName)`: Cambiar rol
- `getGroups()`: Lista de grupos
- `getGroupsWithMembers()`: Grupos con miembros
- `deleteGroup(groupName, confirmName)`: Eliminar grupo
- `createGroup(name, displayName, description, color, icon)`: Crear grupo
- `getParents()`: Lista de padres
- `linkStudentToParent(parentId, studentId)`: Vincular
- `unlinkStudentFromParent(parentId, studentId)`: Desvincular
- `searchStudents(query)`: Buscar estudiantes

**B. Teacher**:
- `createMeeting(title, description, allowedGroups, allowedUsers, meetingType)`: Crear reunión
- `getSchedules()`: Obtener horarios (con conversión UTC→Local)
- `createSchedule(...)`: Programar clase (con conversión Local→UTC)
- `deleteSchedule(id)`: Eliminar horario
- `unlockAchievement(studentId, achievementId)`: Otorgar logro

**C. Student**:
- `getAchievements()`: Logros generales
- `getStudentAchievements(studentId)`: Logros de un estudiante
- `joinMeeting(channelName)`: Unirse a reunión
- `getActiveMeetings()`: Reuniones activas disponibles
- `endMeeting(meetingId)`: Finalizar reunión

**D. Attendance**:
- `recordAttendance(meetingDate, studentIds, meetingId, notes)`: Registrar asistencia
- `getTeacherAttendance(teacherId, startDate, endDate)`: Asistencia de maestro
- `getStudentAttendance(studentId)`: Asistencia de estudiante
- `getAttendanceByDate(date)`: Asistencia por fecha
- `assignAchievementsToAttendance(attendanceId, achievementIds)`: Asignar logros

**E. Participant Status**:
- `setEnteredCallStatus(meetingId)`: Marcar entrada a llamada
- `setBackToWaitingRoomStatus(meetingId)`: Marcar regreso a sala de espera
- `leaveMeeting(meetingId)`: Marcar salida
- `sendHeartbeat(meetingId)`: Heartbeat para detectar caídas

**F. Students Status**:
- `getStudentsStatus(meetingId)`: Estado de estudiantes en reunión

**Conversión de Zona Horaria**:
- `_localToUtcSchedule()`: Convierte horario local a UTC para enviar al servidor
- `_utcToLocalSchedule()`: Convierte horario UTC del servidor a local para mostrar

---

#### **6. `lib/services/deep_link_service.dart`** — Servicio de Deep Links

**Propósito**: Procesar deep links de OAuth desde Firebase Hosting.

**Protocolo**: `stemforall://auth-callback?access_token=...&refresh_token=...`

**Flujo**:
1. Recibir link (puede venir como List<int>, String JSON, o String plano)
2. Parsear URI
3. Validar scheme (`stemforall`), host (`auth-callback`), path (`/`)
4. Extraer tokens de query parameters o fragmento hash
5. Si hay `access_token` + `refresh_token`:
   - Llamar `setSession(refreshToken)` (Supabase Flutter v2)
6. Si hay `authCode` (PKCE):
   - Llamar `exchangeCodeForSession(authCode)`
7. Mostrar SnackBar de éxito/error

**Manejo de Errores**:
- Si no hay tokens → Exception
- Si error en URL → Mostrar error en SnackBar naranja
- Si error en setSession → Mostrar error en SnackBar rojo

---

#### **7. `lib/video_call/video_call_screen.dart`** — Pantalla de Videollamada

**Propósito**: Interfaz principal de videoconferencia con Agora.

**Características**:

**A. Inicialización**:
- Crear `VideoCallController` con channel, token, uid, meetingId
- Registrar controlador en `MeetingCleanupService`
- Inicializar Agora (`_initAgora()`)
- Configurar canal de Supabase Realtime para señales
- Auto-polling de lista de estudiantes (cada 10s)

**B. Panel de Estudiantes**:
- Lista de estudiantes con estados:
  - 🟢 `in_call`: En clase
  - 🟠 `waiting`: Sala de espera
  - 🔴 `left`: Salió
  - ⚫ `absent`: Ausente
- Acciones por estudiante:
  - **Admitir** (solo si está en `waiting`): Envía broadcast `admit_student`
  - **Evaluar** (cualquier estado): Abre diálogo de asistencia + logros
  - **Expulsar** (solo si está en `waiting` o `in_call`): Envía broadcast `kick_student`

**C. Chat Integrado**:
- Panel desplegable derecho (350px)
- Chat en tiempo real via Agora RTM
- Botón de cerrar en esquina superior derecha

**D. Pizarra Colaborativa**:
- Botón en barra de controles
- Abre ventana secundaria con `WhiteboardOverlay`
- Monitoreo de cierre con polling cada 500ms

**E. Bubble Mode**:
- Minimizar ventana a 220x160px
- Siempre encima (`alwaysOnTop`)
- Posición fija en esquina (40, 40)
- Botón de expandir en esquina superior derecha

**F. Evaluación de Estudiantes**:
- Dialog con:
  1. Registro de asistencia (API)
  2. Lista de logros disponibles (checkboxes)
  3. Logros ya otorgados (checked)
  4. Botón "Guardar Evaluación"

**G. Heartbeat**:
- Envío periódico de heartbeat al backend
- Detección de caídas de conexión

---

#### **8. `backend/server.js`** — API Backend de edu_mi_app

**Propósito**: Servidor Express con lógica de negocio completa.

**Dependencias**:
- `express`: Framework
- `cors`: CORS con whitelist
- `helmet`: Headers de seguridad
- `express-rate-limit`: Rate limiting (5000 req/15min)
- `dotenv`: Variables de entorno

**Middleware**:
- `trust proxy`: 1 (confía en Render/Railway)
- CORS con origen dinámico desde `ALLOWED_ORIGINS`
- Rate limiter en `/api/`
- JSON parser

**Rutas**:
- `/api/meetings` → meetingsRoutes
- `/api/admin` → adminRoutes
- `/api/notifications` → notificationsRoutes
- `/api/achievements` → achievementsRoutes
- `/api/attendance` → attendanceRoutes

**Health Check**: `GET /api/health`

**Manejo de Errores**:
- Middleware de errores con stack trace en desarrollo
- Rutas no encontradas (404)
- Promesas rechazadas no capturadas
- Excepciones no capturadas (exit(1))

---

#### **9. `backend/routes/meetings.js`** — Rutas de Reuniones

**Propósito**: CRUD completo de reuniones virtuales y lógica de Agora.

**Endpoints**:

**A. `POST /create`**:
- Validar canal (1-64 chars, letras/números/-/_)
- Verificar que no exista canal activo duplicado
- Generar token Agora RTC (publisher, expiración customizable)
- Insertar reunión en BD
- Retornar: `{meeting: {id, channelName, title, token, expiresAt, joinUrl}}`

**B. `POST /join`**:
- Validar canal
- Buscar reunión activa
- **Manejo de reuniones programadas** (canal empieza con `sched-`):
  - Extraer UUID de schedule
  - Buscar en `class_schedules`
  - Crear reunión automáticamente si está en horario
- Verificar expiración (soft delete si expiró)
- Generar token con tiempo restante
- Registrar participante en `meeting_participants` (waiting)
- Retornar token y datos de reunión

**C. `GET /active`**:
- Obtener perfil del usuario (rol, grupo)
- **Procesamiento Just-In-Time de horarios**:
  - Obtener horarios de hoy/ayer (por zona horaria UTC)
  - Determinar si están activos ahora
  - Crear reuniones virtuales automáticamente
- Filtrar reuniones por rol:
  - Admin: Ve todas
  - Teacher: Ve las de su grupo o que creó
  - Student: Ve las de su grupo o donde está invitado
- Obtener nombres de creadores
- Retornar lista formateada

**D. `POST /:meetingId/end`**:
- Validar que sea creador o admin
- Soft delete: `is_active = false`, `ended_at = timestamp`
- Emitir evento Realtime `meeting_ended` para desconectar estudiantes
- Manejar error si columna `ended_at` no existe

**E. `POST /:meetingId/heartbeat`**:
- Actualizar `last_heartbeat` del participante
- Usado para detectar caídas

**F. `POST /:meetingId/entered-call`**:
- Marcar participante como `in_call`
- `last_heartbeat` = ahora, `left_at` = null

**G. `POST /:meetingId/back-to-waiting-room`**:
- Marcar participante como `waiting`
- `last_heartbeat` = null, `left_at` = null

**H. `POST /:meetingId/leave`**:
- Marcar `left_at` = timestamp actual

**I. `POST /:meetingId/user-left`**:
- Registro informativo de desconexión (no requiere auth)
- Usado cuando Agora detecta `onUserOffline`

**J. `POST /cleanup-inactive`**:
- Limpiar participantes sin heartbeat en últimos 3 minutos
- Marcar como `left_at`

**K. `GET /schedules`**:
- Obtener horarios según rol:
  - Teacher: Sus propios horarios
  - Student: Horarios de su grupo

**L. `POST /schedules`**:
- Crear nueva clase programada
- Solo teachers y admins
- Validar grupo

**M. `DELETE /schedules/:id`**:
- Eliminar horario (solo el creador)

**N. `GET /:meetingId/students-status`**:
- Obtener lista de estudiantes del grupo
- Incluir estado actual (waiting/in_call/absent/left)
- Útil para panel de control del maestro

---

#### **10. `functions/index.js`** — Firebase Functions

**Propósito**: Cloud Functions para lógica serverless.

**Estado Actual**: Placeholder (solo configuración global).

**Configuración**:
- `maxInstances: 10` (límite de contenedores simultáneos)

**Uso Futuro**:
- Notificaciones push
- Triggers de base de datos
- Procesamiento asíncrono

---

## 🔧 CONFIGURACIÓN Y DESPLIEGUE

### Variables de Entorno

**App_Supervisor**:
- `SUPABASE_URL`: URL de Supabase
- `SUPABASE_ANON_KEY`: Clave pública anónima
- `APP_URL`: URL de callback OAuth

**edu_mi_app (.env)**:
- `SUPABASE_URL`: URL de Supabase
- `SUPABASE_ANON_KEY`: Clave pública anónima
- `BACKEND_URL`: URL del backend Express (Render/Railway)
- `AGORA_APP_ID`: ID de app de Agora
- `AGORA_APP_CERTIFICATE`: Certificado de Agora

**Backend Express**:
- `PORT`: Puerto (10000 en Render)
- `SUPABASE_URL`: URL de Supabase
- `SUPABASE_ANON_KEY`: Clave anónima
- `NODE_ENV`: development/production
- `ALLOWED_ORIGINS`: Orígenes permitidos para CORS
- `RATE_LIMIT_WINDOW_MS`: Ventana de rate limit (default: 15min)
- `RATE_LIMIT_MAX_REQUESTS`: Límite de peticiones (default: 5000)
- `TOKEN_EXPIRATION_TIME`: Expiración de tokens Agora (default: 3600s)

### URLs de Despliegue

**App_Supervisor**:
- Frontend: `https://educoparent-callback.web.app` (Firebase Hosting)
- Backend: `https://app-supervisor-backend.onrender.com` (Render)
- Login: `https://educoparent-callback.web.app/index.html`
- Dashboard: `https://educoparent-callback.web.app/app.html`

**edu_mi_app**:
- Aplicación de escritorio (ejecutable .exe/.app)
- Deep link protocol: `stemforall://`

**Supabase**:
- URL: `https://tcbmlktpzshltvmoirjs.supabase.co`
- Proyecto compartido entre App_Supervisor y edu_mi_app

---

## 🔐 SEGURIDAD

### Autenticación
- Supabase Auth (JWT tokens)
- OAuth 2.0 con Google
- Row Level Security (RLS) en todas las tablas
- Tokens de Agora con expiración

### Autorización
- Políticas RLS por rol (parent, student, teacher, administrator)
- Validación de pertenencia de recursos
- Rate limiting en API

### Datos Sensibles
- Tokenización de pagos (PCI DSS compliant)
- No almacenamiento de tarjetas de crédito
- HTTPS obligatorio en producción
- Variables de entorno para credenciales

---

## 🧪 MODO DE PRUEBA (Local Fallback)

**Activación**: No configurar credenciales de Supabase.

**Comportamiento**:
- Indicador: "LOCAL FALLBACK (Sin Conexión)"
- Datos cargados desde `js/data.js` (mock)
- Login simulado (cualquier email/password)
- Registro simulado
- API backend en modo mock

**Uso**:
- Desarrollo frontend sin backend
- Demos y presentaciones
- Testing de UI/UX

---

## 📊 FLUJOS PRINCIPALES

### 1. Autenticación de Padre
```
1. Padre abre App_Supervisor/index.html
2. Ingresa email/contraseña o Google OAuth
3. Supabase valida credenciales
4. Se crea perfil con rol='parent'
5. Redirige a app.html
6. Carga estudiantes vinculados (parent_students)
7. Muestra dashboard con datos reales
```

### 2. Inicio de Clase Virtual (Maestro)
```
1. Maestro abre edu_mi_app
2. Va a TeacherDashboard
3. Crea reunión con título, descripción, grupos
4. Backend genera token Agora
5. Backend inserta reunión en BD
6. Estudiantes ven reunión en "Clases Activas"
7. Estudiante hace clic en "Entrar a Clase"
8. Se abre sala de espera (ventana secundaria)
9. Maestro ve estudiante en "Sala de espera"
10. Maestro hace clic en "Admitir"
11. Estudiante entra a videollamada
12. Ambos pueden ver, escuchar, chatear
```

### 3. Evaluación de Estudiante
```
1. Maestro abre panel de estudiantes en videollamada
2. Ve lista con estados (waiting/in_call/left)
3. Haz clic en "Evaluar" sobre estudiante
4. Se registra asistencia automáticamente
5. Se muestra lista de logros disponibles
6. Maestro marca logros otorgados (checkboxes)
7. Guarda evaluación
8. Backend registra en student_achievements
9. Padre ve logros en App_Supervisor
```

### 4. Alerta Automática por Baja Nota
```
1. Backend recibe POST /api/rules-engine/evaluate
2. Evalúa array de grades
3. Si alguna nota < 70:
   - Genera mensaje de alerta
   - Inserta en tabla alerts
   - Retorna alerta con acción "schedule_meeting"
4. Frontend muestra notificación al padre
5. Padre puede programar reunión con maestro
```

---

## 🛠️ TECNOLOGÍAS UTILIZADAS

### Frontend
- **HTML5/CSS3/JavaScript ES6+**: App_Supervisor
- **Flutter 3.x**: edu_mi_app (Windows/Mac/Linux)
- **Supabase Flutter SDK**: Cliente de base de datos
- **Agora RTC Engine**: Video/audio en tiempo real
- **Table Calendar**: Calendario interactivo

### Backend
- **Node.js + Express**: API REST
- **Supabase JS SDK**: Cliente de base de datos
- **Helmet**: Seguridad HTTP
- **CORS**: Control de acceso
- **Express Rate Limit**: Protección contra abuso

### Base de Datos
- **PostgreSQL**: Motor de BD
- **Supabase**: Plataforma gestionada
- **Row Level Security**: Seguridad a nivel de fila
- **Realtime**: Suscripciones en tiempo real

### Hosting/Deploy
- **Firebase Hosting**: Frontend web + OAuth callback
- **Render**: Backend Express
- **Firebase Functions**: Cloud functions (futuro)

### Servicios Externos
- **Google OAuth 2.0**: Autenticación social
- **Agora.io**: Videoconferencias WebRTC
- **Firebase Auth**: Autenticación (alternativa)

---

## 📝 NOTAS ADICIONALES

### Convenciones de Código
- **IDs**: UUIDs v4 para todas las entidades
- **Timestamps**: ISO 8601 con timezone UTC
- **Estados**: `is_active` para soft deletes
- **Roles**: `parent`, `student`, `teacher`, `administrator`

### Limitaciones Conocidas
- App_Supervisor solo funciona en navegadores modernos (ES6+)
- edu_mi_app requiere Windows 10+ para ventanas múltiples
- Agora tiene límite de 17 usuarios en plan gratuito
- Supabase free tier: 500MB de BD, 2GB de storage

### Mejoras Futuras
- [ ] Notificaciones push (Firebase Cloud Messaging)
- [ ] Chat bidireccional padre-maestro
- [ ] Exportación de reportes PDF
- [ ] Modo offline con sincronización
- [ ] Soporte para múltiples idiomas
- [ ] App móvil (Flutter iOS/Android)
- [ ] Integración con Google Classroom
- [ ] Analytics y métricas avanzadas

---

## 📞 SOPORTE

**Documentación Adicional**:
- `App_Supervisor/INSTRUCCIONES_DETALLADAS.md`
- `App_Supervisor/firebase/DEPLOY_HOSTING.md`
- `edu_mi_app/DEPLOY_EN_5_PASOS.md`
- `edu_mi_app/INDICE_DOCUMENTOS.md`

**Repositorio**: https://github.com/YamilUchani/Comunication_System

**Última Actualización**: Junio 2025

---

**Documento generado por**: Sistema de Documentación Automática  
**Versión**: 1.0.0  
**Autor**: Google DeepMind Antigravity