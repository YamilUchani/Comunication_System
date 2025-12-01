# Guía de Instalación: Firebase CLI y Despliegue

## 📋 Paso a Paso Completo

### Paso 1: Instalar Node.js

Firebase CLI requiere Node.js. Aquí está cómo instalarlo:

#### Opción A: Instalador Oficial (Recomendado)

1. Ve a https://nodejs.org
2. Descarga la versión **LTS** (Long Term Support)
3. Ejecuta el instalador
4. **Importante**: Marca la casilla "Automatically install the necessary tools"
5. Completa la instalación
6. Reinicia tu terminal/PowerShell

#### Opción B: Con Chocolatey (si ya lo tienes)

```powershell
choco install nodejs-lts
```

#### Opción C: Con Scoop (si ya lo tienes)

```powershell
scoop install nodejs-lts
```

### Paso 2: Verificar Instalación

Abre una **nueva** terminal PowerShell y ejecuta:

```powershell
node --version
# Debería mostrar: v18.x.x o v20.x.x

npm --version
# Debería mostrar: 9.x.x o 10.x.x
```

### Paso 3: Instalar Firebase CLI

```powershell
npm install -g firebase-tools
```

Esto tomará ~1-2 minutos.

### Paso 4: Verificar Firebase CLI

```powershell
firebase --version
# Debería mostrar: 13.x.x o similar
```

### Paso 5: Iniciar Sesión en Firebase

```powershell
firebase login
```

- Se abrirá tu navegador
- Inicia sesión con tu cuenta de Google
- Autoriza Firebase CLI
- Debería mostrar: "✔ Success! Logged in as tu@email.com"

### Paso 6: Inicializar Firebase en tu Proyecto

```powershell
cd "G:\Github\Software de administracion\Comunication_System\edu_mi_app"

firebase init
```

**Configuración:**

1. **¿Qué quieres configurar?**
   - Presiona Espacio en: `Functions` (debe aparecer con *)
   - Presiona Espacio en: `Hosting` (debe aparecer con *)
   - Presiona Enter

2. **¿Usar proyecto existente o crear uno nuevo?**
   - Selecciona: `Use an existing project`
   - Elige: `stemforall-f57ac` (o el nombre de tu proyecto)

3. **Configuración de Functions:**
   - Lenguaje: `JavaScript`
   - ¿ESLint?: `Yes`
   - ¿Instalar dependencias?: `Yes`

4. **Configuración de Hosting:**
   - Public directory: `firebase/public`
   - ¿Single-page app?: `No`
   - ¿GitHub deploys?: `No`

### Paso 7: Configurar Variables de Entorno

Firebase Cloud Functions usa configuración especial para variables sensibles:

```powershell
# Configurar Supabase
firebase functions:config:set supabase.url="https://xxxxx.supabase.co"
firebase functions:config:set supabase.service_key="tu_service_key_de_supabase"

# Configurar Agora
firebase functions:config:set agora.app_id="tu_app_id"
firebase functions:config:set agora.app_certificate="tu_certificado"

# Verificar configuración
firebase functions:config:get
```

**¿Dónde obtener estas credenciales?**

1. **Supabase URL y Service Key:**
   - https://supabase.com/dashboard
   - Tu proyecto > Settings > API
   - Copia: "URL" y "service_role key"

2. **Agora App ID y Certificate:**
   - https://console.agora.io
   - Tu proyecto > Config
   - Copia: "App ID" y "Primary certificate"

### Paso 8: Instalar Dependencias de Functions

```powershell
cd firebase/functions
npm install
cd ../..
```

### Paso 9: Desplegar Hosting

```powershell
firebase deploy --only hosting
```

Deberías ver:
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/...
Hosting URL: https://stemforall-f57ac.firebaseapp.com
```

### Paso 10: Desplegar Cloud Functions

```powershell
firebase deploy --only functions
```

**Nota:** Este paso puede tomar **5-10 minutos** la primera vez.

Deberías ver:
```
✔  functions[api(us-central1)]: Successful create operation.
✔  functions[syncUserToSupabase(us-central1)]: Successful create operation.
✔  functions[cleanupUserFromSupabase(us-central1)]: Successful create operation.

Function URL (api): https://us-central1-stemforall-f57ac.cloudfunctions.net/api
```

### Paso 11: Verificar que Funciona

```powershell
# Verificar Hosting
curl https://stemforall-f57ac.firebaseapp.com

# Verificar Cloud Functions
curl https://us-central1-stemforall-f57ac.cloudfunctions.net/api/health
```

## 🎯 Actualizar Flutter para Usar Firebase

### 1. Actualizar pubspec.yaml

```yaml
dependencies:
  # Firebase
  firebase_core: ^2.24.0
  firebase_auth: ^4.15.0
  google_sign_in: ^6.1.6
  
  # Existentes
  supabase_flutter: ^2.0.0
  flutter_dotenv: ^5.1.0
  agora_rtc_engine: ^6.3.0
  http: ^1.1.0
```

```bash
flutter pub get
```

### 2. Configurar Firebase en Flutter

```bash
# Instalar FlutterFire CLI
dart pub global activate flutterfire_cli

# Configurar proyecto (esto crea firebase_options.dart)
flutterfire configure
```

Selecciona tu proyecto `stemforall-f57ac`.

### 3. Actualizar .env

```env
# Firebase Cloud Functions URL
BACKEND_URL=https://us-central1-stemforall-f57ac.cloudfunctions.net/api

# Supabase (solo para DB)
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=tu_anon_key

# Agora (solo App ID, el certificate está en Firebase)
AGORA_APP_ID=tu_app_id
```

### 4. Actualizar main.dart

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase PRIMERO
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Luego Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  runApp(const MyApp());
}
```

### 5. Usar el Servicio de Reuniones

Ahora en tu app, podrás crear reuniones así:

```dart
import '../services/meeting_service.dart';
import '../services/firebase_auth_service.dart';

// En tu pantalla de crear reunión:
final meetingService = MeetingService();
final authService = FirebaseAuthService();

try {
  // Crear reunión (llama a Firebase Cloud Function)
  final meeting = await meetingService.createMeeting(
    channelName: 'clase-matematicas-${DateTime.now().millisecondsSinceEpoch}',
    title: 'Clase de Matemáticas',
    description: 'Geometría - Capítulo 5',
  );

  print('Reunión creada: ${meeting['id']}');
  print('Token de Agora: ${meeting['token']}');
  print('URL para compartir: ${meeting['joinUrl']}');

  // Navegar a la videollamada
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VideoCallScreen(
        channelName: meeting['channelName'],
        token: meeting['token'], // Token SEGURO generado en Firebase
        userName: authService.currentUser?.displayName ?? 'Usuario',
      ),
    ),
  );
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

## ✅ Checklist de Configuración

- [ ] Node.js instalado
- [ ] Firebase CLI instalado
- [ ] `firebase login` completado
- [ ] `firebase init` ejecutado
- [ ] Variables de configuración establecidas con `functions:config:set`
- [ ] Dependencias de functions instaladas
- [ ] Hosting desplegado
- [ ] Cloud Functions desplegadas
- [ ] Firebase configurado en Flutter
- [ ] `.env` actualizado con la URL de Cloud Functions

## 🚀 Comandos Útiles Futuros

```powershell
# Ver logs de Cloud Functions
firebase functions:log

# Redesplegar solo hosting (rápido)
firebase deploy --only hosting

# Redesplegar solo functions
firebase deploy --only functions

# Redesplegar todo
firebase deploy

# Probar localmente
firebase emulators:start

# Ver estado del proyecto
firebase projects:list
```

## 🐛 Solución de Problemas

### "firebase: command not found"

Reinicia tu terminal después de instalar Node.js/Firebase CLI.

### "Insufficient permissions"

Asegúrate de estar autenticado:
```powershell
firebase login --reauth
```

### Functions toman mucho tiempo

Es normal la primera vez. Ten paciencia.

### Error al desplegar

Verifica que las variables de configuración estén establecidas:
```powershell
firebase functions:config:get
```

## 📚 Próximos Pasos Después del Despliegue

1. **Probar Google Sign-In**
   ```bash
   flutter run -d windows
   # Hacer clic en "Continuar con Google"
   ```

2. **Verificar Perfil en Supabase**
   - Ir a Supabase > Table Editor > profiles
   - Deberías ver tu perfil creado automáticamente

3. **Crear Primera Reunión**
   - Desde la app, crear reunión
   - Ver en Supabase > Table Editor > meetings

4. **Verificar Logs**
   ```bash
   firebase functions:log
   ```

---

**¿Necesitas ayuda en algún paso específico?** Puedo guiarte paso a paso.

**Resumen:** Sí, podrás crear reuniones desde tu app. Firebase maneja todo de forma segura y automática. Solo necesitas completar estos pasos de configuración una vez.
