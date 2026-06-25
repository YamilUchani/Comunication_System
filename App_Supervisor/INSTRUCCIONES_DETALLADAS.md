# Guía de Configuración y Despliegue de la Plataforma
## De Supervisor a Co-Aprendiz: Ecosistema Educativo para Padres

Esta guía detalla los pasos para poner en marcha e integrar la plataforma utilizando **Supabase** (Base de datos y tiempo real), **Render** (Servidor Express/API) y **Firebase** (Autenticación y Notificaciones Push).

---

## 🏗️ Arquitectura del Sistema

El sistema está diseñado para operar bajo un enfoque híbrido de prioridad asíncrona:
1. **Frontend (Cliente SPA)**: Interfaz en HTML, CSS vanilla y JS que se conecta a Firebase para login y a Supabase para la consulta de notas, tareas y chat.
2. **Servidor API (Render)**: Procesa reglas complejas de negocio (ej. motor de alertas automatizado cuando bajan las notas) y transacciones financieras seguras.
3. **Base de Datos (Supabase)**: Almacena los registros con políticas RLS (Row Level Security) para proteger los datos de los estudiantes.

---

## 🗄️ Paso 1: Configuración de Supabase (Prioridad 1)

Supabase se encarga de almacenar de forma relacional toda la información escolar, calendarios y mensajería.

### Instrucciones:
1. Inicia sesión en Supabase y abre el proyecto compartido con `edu_mi_app`.
2. Ve a la pestaña **SQL Editor** en el panel izquierdo de Supabase.
3. Crea un nuevo Query e introduce las instrucciones del archivo [schema.sql](file:///g:/Github/Software de administracion/App_Supervisor/supabase/schema.sql).
4. Haz clic en **Run** para crear la estructura de tablas y las políticas de Row Level Security (RLS).
5. Ve a **Project Settings** > **API**.
6. Copia los valores de:
   - **Project API URL** (URL del proyecto)
   - **anon public** (Clave de API anónima pública)
7. Configura la conexión compartida y la URL propia de Supervisor en `js/app-supervisor-config.js`:
   ```javascript
   window.APP_SUPERVISOR_CONFIG = {
     supabaseUrl: "https://TU-PROJECT-REF.supabase.co",
     supabaseAnonKey: "TU_CLAVE_PUBLICA_ANON",
     appUrl: "https://yamiluchani.github.io/Comunication_System/"
   };
   ```
8. En **Authentication → URL Configuration → Redirect URLs**, agrega:
   `https://yamiluchani.github.io/Comunication_System/`

---

## 🚀 Paso 2: Configuración y Despliegue en Render (Prioridad 2)

Render aloja el backend Node/Express encargado del motor de evaluación automática y pasarela de pagos simulada.

### Instrucciones:
1. Sube tu código a un repositorio privado de GitHub (incluyendo la carpeta `/server`).
2. Crea una cuenta en [Render](https://render.com).
3. Selecciona **New +** > **Web Service**.
4. Conecta tu repositorio de GitHub.
5. En la configuración del servicio de Render, especifica:
   - **Name**: `app-supervisor-backend`
   - **Root Directory**: `server`
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
6. En la sección **Environment Variables**, añade las siguientes claves:
   - `PORT`: `10000` (o el puerto que prefieras)
   - `SUPABASE_URL`: Tu URL de Supabase.
   - `SUPABASE_ANON_KEY`: Tu clave anónima de Supabase.
7. Haz clic en **Deploy Web Service**.
8. Una vez desplegado, copia la URL pública que te proporciona Render (ej: `https://app-supervisor-backend.onrender.com`).
9. Configura esta URL en el cliente frontend (`js/app.js`) para que el panel de control apunte al servidor desplegado en la nube en lugar de `localhost`.

---

## 🔥 Paso 3: Configuración de Firebase (Prioridad 3)

Firebase gestiona el inicio de sesión seguro del padre y las notificaciones automáticas por celular/navegador.

### Instrucciones:
1. Crea un proyecto en la [Consola de Firebase](https://console.firebase.google.com).
2. Agrega una **Web App** al proyecto.
3. Copia el objeto de configuración de Firebase (`firebaseConfig`).
4. Pega estos datos en el archivo [firebase-config.js](file:///g:/Github/Software de administracion/App_Supervisor/js/firebase-config.js):
   ```javascript
   const firebaseConfig = {
     apiKey: "TU_API_KEY",
     authDomain: "TU_AUTH_DOMAIN",
     projectId: "TU_PROJECT_ID",
     storageBucket: "TU_STORAGE_BUCKET",
     messagingSenderId: "TU_MESSAGING_SENDER_ID",
     appId: "TU_APP_ID"
   };
   ```
5. En la consola de Firebase, ve a **Authentication** y activa el método de inicio de sesión por **Email/Contraseña** y opcionalmente **Google**.
6. Ve a **Cloud Messaging** si deseas configurar las notificaciones automáticas mediante web push.

---

## 🔌 Mecanismo de Fallback Inteligente (Graceful Fallback)

El sistema incluye un sistema de fallback integrado para que el portal sea completamente operable en local aun sin configurar las credenciales de nube:
- **Sin Credenciales**: El indicador de estado de conexión mostrará `LOCAL FALLBACK (Sin Conexión a Nube)`. La aplicación cargará los datos simulados desde `js/data.js` permitiendo testear todas las vistas, simulaciones de pago y chats inmediatamente.
- **Con Credenciales**: El estado mostrará `CONECTADO A SUPABASE CLOUD`. Los flujos leerán y guardarán la información directamente en las tablas correspondientes en tiempo real.
