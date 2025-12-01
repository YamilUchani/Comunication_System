# Guía Completa: Firebase + Google Sign-In + Cloud Functions

## 📚 Índice

1. [¿Por qué Firebase?](#por-qué-firebase)
2. [Configuración Inicial de Firebase](#configuración-inicial-de-firebase)
3. [Configurar Google Sign-In](#configurar-google-sign-in)
4. [Configurar Firebase Cloud Functions](#configurar-firebase-cloud-functions)
5. [Configurar Flutter con Firebase](#configurar-flutter-con-firebase)
6. [Sincronización Firebase ↔ Supabase](#sincronización-firebase--supabase)
7. [Desplegar Cloud Functions](#desplegar-cloud-functions)
8. [Pruebas Completas](#pruebas-completas)
9. [FAQ y Solución de Problemas](#faq-y-solución-de-problemas)

---

## ¿Por qué Firebase?

### Ventajas de usar Firebase

✅ **Google Sign-In integrado** - Fácil de configurar  
✅ **Cloud Functions gratuitas** - 2 millones de invocaciones/mes  
✅ **Hosting gratis** - Para tu API  
✅ **Sincronización automática** - Con Supabase para la BD  
✅ **Escalable** - Google Cloud Platform detrás  

### Arquitectura Final

```
Usuario
  ↓
1. Login con Google (Firebase Auth)
  ↓
2. Token JWT de Firebase
  ↓
3. Cloud Function verifica token
  ↓
4. Sincroniza con Supabase (BD)
  ↓
5. Genera token de Agora
  ↓
6. Usuario inicia videollamada
```

---

## Configuración Inicial de Firebase

### Paso 1: Crear Proyecto en Firebase

1. Ve a https://console.firebase.google.com
2. Haz clic en "**Agregar proyecto**" (Add project)
3. Configura:
   - **Nombre del proyecto**: `edumi-app` (o el que prefieras)
   - **Google Analytics**: Desactiva (opcional)
4. Haz clic en "**Crear proyecto**"
5. Espera ~30 segundos

### Paso 2: Agregar App de Windows/Android/iOS

#### Para Windows (Desktop):

1. En la consola, haz clic en el ícono de **Web** (`</>`)
2. Registra tu app:
   - **Nombre de la app**: `EduMi Windows`
   - **Firebase Hosting**: No marcar
3. Copia la configuración que aparece (la usaremos después)
4. Haz clic en "**Continuar en la consola**"

#### Para Android (opcional):

1. Haz clic en el ícono de **Android**
2. Registra:
   - **Nombre del paquete**: `com.ejemplo.edumi` (debe coincidir con tu `build.gradle`)
   - **Apodo**: `EduMi Android`
   - **SHA-1**: Obtén con `cd android && ./gradlew signingReport`
3. Descarga `google-services.json`
4. Colócalo en `android/app/`

### Paso 3: Instalar Firebase CLI

```bash
# Instalar Firebase CLI globalmente
npm install -g firebase-tools

# Verificar instalación
firebase --version

# Iniciar sesión
firebase login
```

Se abrirá tu navegador para autenticarte con Google.

### Paso 4: Inicializar Firebase en el Proyecto

```bash
# En la raíz del proyecto Flutter
cd "G:\Github\Software de administracion\Comunication_System\edu_mi_app"

# Inicializar Firebase
firebase init
```

Selecciona:
- ❌ Hosting
- ✅ **Functions** (presiona Espacio para seleccionar)
- ❌ Firestore
- ❌ Storage

Configuración:
- **Use an existing project**: Selecciona `edumi-app`
- **Language**: JavaScript
- **ESLint**: Yes
- **Install dependencies**: Yes

---

## Configurar Google Sign-In

### Paso 1: Habilitar Google Auth en Firebase

1. En la consola de Firebase, ve a **Authentication**
2. Haz clic en "**Get Started**"
3. Ve a la pestaña "**Sign-in method**"
4. Haz clic en "**Google**"
5. **Habilita** el proveedor
6. Configura:
   - **Nombre público del proyecto**: `EduMi App`
   - **Correo de soporte**: tu@email.com
7. **Guarda**

### Paso 2: Obtener Credenciales para Windows

Para aplicaciones de escritorio con Google Sign-In:

1. Ve a https://console.cloud.google.com
2. Selecciona tu proyecto Firebase
3. Ve a **APIs & Services** > **Credentials**
4. Haz clic en "**CREATE CREDENTIALS**" > "**OAuth client ID**"
5. Tipo de aplicación: **Desktop app**
6. Nombre: `EduMi Windows Client`
7. Crea y **descarga el JSON**
8. Copia el **Client ID** (lo necesitarás)

### Paso 3: Configurar SHA en Firebase (Para Windows)

Para Windows, necesitas configurar las huellas SHA:

1. En tu proyecto, ejecuta:
   ```bash
   cd windows
   # Windows usa certificados, no SHA como Android
   # Firebase detectará automáticamente la app de Windows
   ```

---

## Configurar Firebase Cloud Functions

### Paso 1: Copiar Archivos de Functions

Los archivos ya están creados en `firebase/functions/`:
- `index.js` - Cloud Functions con la API
- `package.json` - Dependencias

### Paso 2: Configurar Variables de Entorno

Firebase usa `firebase functions:config` para variables sensibles:

```bash
# Configurar Supabase
firebase functions:config:set supabase.url="https://xxxxx.supabase.co"
firebase functions:config:set supabase.service_key="eyJhbGc..."

# Configurar Agora
firebase functions:config:set agora.app_id="tu_app_id"
firebase functions:config:set agora.app_certificate="tu_certificado"

# Ver configuración
firebase functions:config:get
```

### Paso 3: Instalar Dependencias

```bash
cd firebase/functions
npm install
```

### Paso 4: Probar Localmente (Emulador)

```bash
# Descargar configuración local
firebase functions:config:get > .runtimeconfig.json

# Iniciar emulador
firebase emulators:start --only functions
```

Deberías ver:
```
✔  functions: Emulator started at http://127.0.0.1:5001
```

### Paso 5: Probar la API Localmente

```bash
# Health check
curl http://127.0.0.1:5001/edumi-app/us-central1/api/health
```

---

## Configurar Flutter con Firebase

### Paso 1: Instalar FlutterFire CLI

```bash
# Activar FlutterFire CLI
dart pub global activate flutterfire_cli

# Configurar proyecto
flutterfire configure
```

Esto creará automáticamente:
- `firebase_options.dart`
- Configuración para todas las plataformas

### Paso 2: Agregar Dependencias en pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  
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

### Paso 3: Crear Servicio de Autenticación con Firebase

Crea `lib/services/firebase_auth_service.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  
  // Stream del estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Usuario actual
  User? get currentUser => _auth.currentUser;
  
  /// Login con Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Iniciar flujo de Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // Usuario canceló el login
        return null;
      }

      // Obtener credenciales de autenticación
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // Crear credencial de Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Iniciar sesión en Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Sincronizar con Supabase (opcional, el trigger ya lo hace)
      await _syncWithSupabase(userCredential.user!);
      
      return userCredential;
    } catch (e) {
      print('Error en Google Sign-In: $e');
      rethrow;
    }
  }
  
  /// Login con email y contraseña
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
  
  /// Registro con email y contraseña
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // Actualizar nombre
    await userCredential.user?.updateDisplayName(fullName);
    
    return userCredential;
  }
  
  /// Cerrar sesión
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
  
  /// Obtener token de Firebase (para las Cloud Functions)
  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }
  
  /// Sincronizar usuario con Supabase (backup, el trigger de Firebase ya lo hace)
  Future<void> _syncWithSupabase(User user) async {
    try {
      final supabase = Supabase.instance.client;
      
      await supabase.from('profiles').upsert({
        'user_id': user.uid,
        'email': user.email,
        'full_name': user.displayName ?? '',
        'avatar_url': user.photoURL ?? '',
        'can_create_meetings': true,
      }, onConflict: 'user_id');
    } catch (e) {
      print('Error sincronizando con Supabase: $e');
      // No lanzar error, el trigger de Firebase lo manejará
    }
  }
}
```

### Paso 4: Actualizar main.dart

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Inicializar Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  runApp(const MyApp());
}
```

### Paso 5: Crear Pantalla de Login con Google

Crea `lib/screens/firebase_login_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';

class FirebaseLoginScreen extends StatefulWidget {
  const FirebaseLoginScreen({super.key});

  @override
  State<FirebaseLoginScreen> createState() => _FirebaseLoginScreenState();
}

class _FirebaseLoginScreenState extends State<FirebaseLoginScreen> {
  final _authService = FirebaseAuthService();
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    
    try {
      final userCredential = await _authService.signInWithGoogle();
      
      if (userCredential != null && mounted) {
        // Navegar a home
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Bienvenido a EduMi App',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _signInWithGoogle,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Image.asset('assets/google_logo.png', height: 24),
              label: const Text('Iniciar sesión con Google'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Paso 6: Actualizar Meeting Service

Actualiza `lib/services/meeting_service.dart` para usar Firebase Auth:

```dart
import 'package:firebase_auth/firebase_auth.dart';

class MeetingService {
  static const String baseUrl = 'https://us-central1-edumi-app.cloudfunctions.net/api';
  
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Obtiene el token de Firebase Auth
  Future<String?> _getAuthToken() async {
    return await _auth.currentUser?.getIdToken();
  }
  
  // ... resto del código igual
}
```

---

## Sincronización Firebase ↔ Supabase

### ¿Por qué mantener ambos?

- **Firebase Auth**: Maneja autenticación (Google Sign-In, Apple, etc.)
- **Supabase**: Base de datos PostgreSQL potente y RLS

### Flujo de Sincronización

```
Usuario se registra en Firebase
  ↓
Cloud Function Trigger: onCreate
  ↓
Crea perfil automático en Supabase
  ↓
Ambas DBs sincronizadas
```

El codigo ya tiene:
- ✅ Trigger `syncUserToSupabase` en `functions/index.js`
- ✅ Trigger `cleanupUserFromSupabase` para eliminar

---

## Desplegar Cloud Functions

### Paso 1: Desplegar

```bash
# Desde la raíz del proyecto
firebase deploy --only functions
```

Verás algo como:
```
✔ functions: Finished running predeploy script.
i  functions: preparing functions directory for uploading...
✔ functions: functions folder uploaded successfully
✔functions[api(us-central1)]: Successful update operation.
✔functions[syncUserToSupabase(us-central1)]: Successful update operation.
✔functions[cleanupUserFromSupabase(us-central1)]: Successful update operation.

✔  Deploy complete!
```

### Paso 2: Obtener URL de la API

```bash
firebase functions:list
```

Copia la URL de la función `api`:
```
https://us-central1-edumi-app.cloudfunctions.net/api
```

### Paso 3: Actualizar Flutter

En `.env`:
```env
BACKEND_URL=https://us-central1-edumi-app.cloudfunctions.net/api
```

---

## Pruebas Completas

### 1. Probar Google Sign-In

```bash
# Ejecutar app
flutter run -d windows

# Probar login con Google
# Debe abrir navegador y autenticar
```

### 2. Verificar Perfil en Supabase

1. Ve a Supabase > Table Editor > `profiles`
2. Deberías ver el perfil del usuario recién cread con Google

### 3. Probar Cloud Function

```bash
# Obtener token (desde Flutter después de login)
# Luego probar:

curl -X POST https://us-central1-edumi-app.cloudfunctions.net/api/meetings/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TU_TOKEN_DE_FIREBASE" \
  -d '{"channelName":"test","title":"Test"}'
```

---

## FAQ y Solución de Problemas

### Error: "Firebase is not initialized"

```dart
// Asegúrate de llamar esto en main():
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

### Error: "google_sign_in not configured"

**Windows**: Verifica que tengas el Client ID de OAuth correcto  
**Android**: Verifica que `google-services.json` esté en `android/app/`

### Error: "Functions deployment failed"

```bash
# Verificar que las variables de entorno estén configuradas
firebase functions:config:get

# Si faltan:
firebase functions:config:set supabase.url="..."
firebase functions:config:set supabase.service_key="..."
firebase functions:config:set agora.app_id="..."
firebase functions:config:set agora.app_certificate="..."
```

### Cloud Function es lenta (cold start)

Las Cloud Functions gratis tienen "cold start" (~3-5 segundos primera vez).

**Soluciones**:
- Usar plan Blaze (pago por uso)
- Hacer "warming" con cron job
- Aceptar el delay inicial

### Costos de Firebase

**Plan Gratuito (Spark)**:
- Cloud Functions: 2M invocaciones/mes, 400K GB-seg, 200K CPU-segundos
- Auth: Ilimitado
- Hosting: 10 GB/mes

**Plan Blaze** (pago por uso):
- Primeras 2M invocaciones gratis
- Después: $0.40 por millón

---

## Checklist Final

### Firebase Console
- [ ] Proyecto creado
- [ ] Google Auth habilitado
- [ ] App de Windows/Android registrada
- [ ] OAuth configurado en Google Cloud

### Firebase CLI
- [ ] Firebase CLI instalado
- [ ] Login completado
- [ ] Proyecto inicializado

### Cloud Functions
- [ ] Dependencias instaladas
- [ ] Variables de entorno configuradas
- [ ] Functions desplegadas
- [ ] URL anotada

### Flutter
- [ ] firebase_core agregado
- [ ] firebase_auth agregado
- [ ] google_sign_in agregado
- [ ] firebase_options.dart creado
- [ ] FirebaseAuthService implementado
- [ ] Login screen con Google creado
- [ ] BACKEND_URL actualizado

### Pruebas
- [ ] Google Sign-In funciona
- [ ] Perfil aparece en Supabase
- [ ] Cloud Functions responden
- [ ] Crear reunión funciona
- [ ] Tokens de Agora generados

---

## Resultado Final

Ahora tienes:
- ✅ **Google Sign-In** funcionando perfectamente
- ✅ **Firebase Auth** como proveedor de identidad
- ✅ **Cloud Functions** alojando tu API
- ✅ **Sincronización automática** Fire base → Supabase
- ✅ **Tokens de Agora** generados de forma segura
- ✅ **Gratis** hasta escalar mucho
- ✅ **Escalable** en Google Cloud

🎉 **¡Sistema completo de videollamadas con Google Sign-In funcionando!** 🎉
