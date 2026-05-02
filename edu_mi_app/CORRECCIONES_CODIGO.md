# 🔧 CORRECCIONES DE CÓDIGO - APLICAR AHORA

Esta guía contiene los cambios específicos a implementar para resolver los problemas críticos identificados.

---

## 📁 ARCHIVO 1: lib/video_call/video_call_screen.dart

### ✏️ CAMBIO 1: Agregar cleanup de timers y realtime channel

**Ubicación:** Método `dispose()` (alrededor de línea 650)

**Antes (INCORRECTO):**
```dart
@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  if (Platform.isWindows) {
    windowManager.removeListener(this);
  }
  super.dispose();
}
```

**Después (CORRECTO):**
```dart
@override
void dispose() {
  print('🧹 [VIDEO_CALL_SCREEN] Iniciando dispose...');
  
  // ✅ Cancelar todos los timers
  _autoStudentRefreshTimer?.cancel();
  _studentsTimer?.cancel();
  print('✅ Timers cancelados');
  
  // ✅ Unsubscribir del canal realtime
  _meetingChannel?.unsubscribe();
  print('✅ Meeting channel unsubscribed');
  
  // ✅ Limpiar controller
  try {
    controller.leaveAndDispose();
    print('✅ VideoCallController disposed');
  } catch (e) {
    print('⚠️ Error disposing controller: $e');
  }
  
  // ✅ Limpiar observadores
  WidgetsBinding.instance.removeObserver(this);
  if (Platform.isWindows) {
    windowManager.removeListener(this);
  }
  
  print('🧹 [VIDEO_CALL_SCREEN] Dispose completado');
  super.dispose();
}
```

---

### ✏️ CAMBIO 2: Mejorar validación en eventos Broadcast

**Ubicación:** Método `_setupMeetingChannel()` (alrededor de línea 85)

**Antes (INCORRECTO):**
```dart
void _setupMeetingChannel() {
  final meetingId = widget.meetingId;
  if (meetingId == null) return;

  print('📡 Suscribiéndose al canal de reunión: meeting:$meetingId');
  _meetingChannel = Supabase.instance.client
      .channel('meeting:$meetingId')
      .onBroadcast(
        event: 'student_calling',
        callback: (payload) {
          final studentName = payload['student_name'] as String?;
          if (studentName != null && mounted) {
            _showStudentCallNotification(studentName);
          }
        },
      )
      .subscribe();
}
```

**Después (CORRECTO):**
```dart
void _setupMeetingChannel() {
  final meetingId = widget.meetingId;
  if (meetingId == null) return;

  print('📡 Suscribiéndose al canal de reunión: meeting:$meetingId');
  _meetingChannel = Supabase.instance.client
      .channel('meeting:$meetingId')
      .onBroadcast(
        event: 'student_calling',
        callback: (payload) {
          try {
            // ✅ Validar estructura del payload
            if (payload is! Map<String, dynamic>) {
              print('⚠️ Payload inválido en student_calling: no es Map');
              return;
            }
            
            final studentName = payload['student_name'];
            if (studentName is! String || studentName.isEmpty) {
              print('⚠️ student_name inválido o vacío en payload');
              return;
            }
            
            if (mounted) {
              _showStudentCallNotification(studentName);
            }
          } catch (e) {
            print('❌ Error procesando student_calling: $e');
          }
        },
      )
      .subscribe();
}
```

---

## 📁 ARCHIVO 2: lib/video_call/video_call_controller.dart

### ✏️ CAMBIO 3: Agregar método dispose() seguro

**Ubicación:** Agregar nuevo método en la clase (alrededor de línea 200)

**Agregar esto:**
```dart
/// 🧹 Limpia recursos del controlador de forma segura
Future<void> leaveAndDispose() async {
  if (_isDisposed) {
    print('ℹ️ Controller ya fue disposed');
    return;
  }
  
  try {
    _joinTimeoutTimer?.cancel();
    print('✅ Join timeout timer cancelado');
    
    // Dejar el canal
    await _engine.leaveChannel();
    print('✅ Dejado el canal de Agora');
    
    // Desregistrar event handler
    _engine.unregisterEventHandler();
    print('✅ Event handler desregistrado');
    
    // Destruir el engine
    await _engine.release(sync: true);
    print('✅ Agora engine destruido');
    
    _isDisposed = true;
    print('🧹 [VIDEO_CALL_CONTROLLER] Dispose completado exitosamente');
  } catch (e) {
    print('❌ Error en leaveAndDispose: $e');
    _isDisposed = true; // Marcar como disposed aún si hay error
    rethrow;
  }
}
```

---

## 📁 ARCHIVO 3: lib/services/session_service.dart

### ✏️ CAMBIO 4: Mejorar error handling en acceptUser()

**Ubicación:** Método `acceptUser()` (alrededor de línea 70)

**Antes (INCORRECTO):**
```dart
Future<void> acceptUser(String sessionId, String userId) async {
  try {
    print('[SESSION_SERVICE] acceptUser INICIADO - sessionId=$sessionId, userId=$userId');

    var updateResult = await _supabase
        .from('session_participants')
        .update({...})
        .eq('session_id', sessionId)
        .eq('user_id', userId)
        .select();

    if (updateResult.isEmpty) {
      await _supabase.from('session_participants').insert({...});
    }
  } catch (e) {
    print('[SESSION_SERVICE] Error en acceptUser: $e');
    rethrow;
  }
}
```

**Después (CORRECTO):**
```dart
Future<void> acceptUser(String sessionId, String userId) async {
  try {
    print('[SESSION_SERVICE] acceptUser INICIADO - sessionId=$sessionId, userId=$userId');

    var updateResult = await _supabase
        .from('session_participants')
        .update({
          'status': AppConstants.sessionStatusActive,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('session_id', sessionId)
        .eq('user_id', userId)
        .select();

    if (updateResult.isEmpty) {
      print('[SESSION_SERVICE] UPDATE no afectó filas, haciendo INSERT...');
      
      // ✅ Obtener datos del usuario para INSERT completo
      final userProfile = await _supabase
          .from('profiles')
          .select('full_name, role')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (userProfile == null) {
        throw Exception('Perfil de usuario no encontrado: $userId');
      }
      
      final userName = userProfile['full_name'] as String? ?? 'Usuario';
      final userRole = userProfile['role'] as String? ?? 'student';
      
      // ✅ Validar INSERT exitoso
      final insertResult = await _supabase
          .from('session_participants')
          .insert({
            'session_id': sessionId,
            'user_id': userId,
            'user_name': userName,
            'role': userRole,
            'status': AppConstants.sessionStatusActive,
            'joined_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'last_seen': DateTime.now().toIso8601String(),
          })
          .select();
      
      if (insertResult.isEmpty) {
        throw Exception('INSERT retornó lista vacía');
      }
      
      print('[SESSION_SERVICE] INSERT exitoso');
    }
    
    print('[SESSION_SERVICE] acceptUser COMPLETADO exitosamente');
  } catch (e) {
    print('[SESSION_SERVICE] ❌ Error en acceptUser: $e');
    rethrow;
  }
}
```

---

## 📁 ARCHIVO 4: lib/services/api_service.dart

### ✏️ CAMBIO 5: Validar BACKEND_URL y token

**Ubicación:** Métodos getter `_baseUrl` y `_getHeaders()`

**Antes (INCORRECTO):**
```dart
static String get _baseUrl => dotenv.env['BACKEND_URL'] ?? '';

static Future<Map<String, String>> _getHeaders() async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) throw Exception('No hay sesión activa');

  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${session.accessToken}',
  };
}
```

**Después (CORRECTO):**
```dart
static String get _baseUrl {
  final url = dotenv.env['BACKEND_URL'];
  if (url == null || url.isEmpty) {
    throw Exception(
      'BACKEND_URL no configurado en .env\n'
      'Asegúrate de tener BACKEND_URL=http://... en tu archivo .env'
    );
  }
  return url;
}

static Future<Map<String, String>> _getHeaders() async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) {
    throw Exception('No hay sesión activa en Supabase');
  }

  final token = session.accessToken;
  if (token.isEmpty) {
    throw Exception('Token de acceso de Supabase está vacío');
  }

  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };
}
```

---

## 📁 ARCHIVO 5: lib/screens/student_waiting_room_screen.dart

### ✏️ CAMBIO 6: Agregar retry logic y mejor error handling

**Ubicación:** Método `_callTeacher()` (alrededor de línea 90)

**Agregar antes del método _callTeacher:**
```dart
/// ✅ Helper: Reintenta una operación con delays exponenciales
Future<void> _retryOperation(
  Future<void> Function() operation, {
  int maxRetries = 3,
  int delayMs = 500,
}) async {
  int lastError;
  for (int i = 0; i < maxRetries; i++) {
    try {
      await operation();
      return;
    } catch (e) {
      lastError = e.hashCode;
      if (i < maxRetries - 1) {
        final delayTime = delayMs * (i + 1); // Exponencial: 500ms, 1000ms, 1500ms
        print('   ⏳ Reintentando en ${delayTime}ms...');
        await Future.delayed(Duration(milliseconds: delayTime));
      }
    }
  }
  throw Exception('Operación falló después de $maxRetries intentos');
}
```

**Después, reemplazar método _callTeacher:**
```dart
Future<void> _callTeacher({bool isAuto = false}) async {
  if (_isCoolingDown && !isAuto) return;
  
  final meetingId = widget.meetingId;
  if (meetingId == null) {
    print('❌ ERROR: meetingId es NULL');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Error: ID de reunión no disponible'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return;
  }

  if (!isAuto) setState(() => _isCoolingDown = true);

  try {
    print('📡 Enviando señal student_calling...');
    print('   - Reunión: $meetingId');
    print('   - Usuario: ${Supabase.instance.client.auth.currentUser?.id}');
    print('   - Nombre: ${widget.userName}');
    
    // ✅ Reintentar broadcast con exponential backoff
    await _retryOperation(
      () => _realtimeChannel!.sendBroadcastMessage(
        event: 'student_calling',
        payload: {
          'student_name': widget.userName,
          'user_id': Supabase.instance.client.auth.currentUser?.id ?? '',
          'is_auto': isAuto,
          'timestamp': DateTime.now().toIso8601String(),
        },
      ),
      maxRetries: 3,
      delayMs: 500,
    );
    
    print('✅ Evento student_calling enviado exitosamente');

    if (mounted && !isAuto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📞 Notificación enviada al maestro'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    // ✅ Reintentar API call también
    print('💾 Registrando estado en BD...');
    await _retryOperation(
      () => ApiService.setBackToWaitingRoomStatus(meetingId),
      maxRetries: 2,
      delayMs: 1000,
    );
    print('✅ Estado guardado en BD');
    
  } catch (e) {
    print('❌ Error en _callTeacher: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Error al contactar maestro: $e'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  if (!isAuto) {
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) setState(() => _isCoolingDown = false);
  }
}
```

---

## 📁 ARCHIVO 6: lib/main.dart

### ✏️ CAMBIO 7: Validar usuario activo en _nextRoute()

**Ubicación:** Función `_nextRoute()` (alrededor de línea 350)

**Antes (INCORRECTO):**
```dart
Future<String> _nextRoute() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return '/login';

  try {
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('full_name, age, role, group_name')
        .eq('user_id', user.id)
        .maybeSingle();
    // ...
  } catch (e) {
    return '/login';
  }
}
```

**Después (CORRECTO):**
```dart
Future<String> _nextRoute() async {
  final user = Supabase.instance.client.auth.currentUser;
  print('🔍 _nextRoute: Checking user: ${user?.id}');

  if (user == null) {
    print('❌ _nextRoute: User is null, returning /login');
    return '/login';
  }

  try {
    print('🔍 _nextRoute: Fetching profile for ${user.id}...');
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('full_name, age, role, group_name, is_active')  // ✅ Agregar is_active
        .eq('user_id', user.id)
        .maybeSingle();

    print('🔍 _nextRoute: Profile result: $profile');

    // ✅ Validar que el usuario esté activo
    if (profile?['is_active'] == false) {
      print('⚠️ _nextRoute: Usuario inactivo, cerrando sesión');
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        print('⚠️ Error cerrando sesión: $e');
      }
      return '/login';
    }

    if (profile == null) {
      print('⚠️ _nextRoute: Profile is null, returning /complete-profile');
      return '/complete-profile';
    }

    if (profile['full_name'] == null ||
        profile['full_name'].toString().isEmpty ||
        profile['age'] == null) {
      print('⚠️ _nextRoute: Profile incomplete (name/age missing)');
      return '/complete-profile';
    }

    final role = profile['role'] as String?;
    print('🔍 _nextRoute: Role: $role');

    if (role == 'administrator') return '/admin-dashboard';

    final groupName = profile['group_name'];
    print('🔍 _nextRoute: Group name: $groupName');

    if (groupName == null || groupName.toString().isEmpty) {
      print('⚠️ _nextRoute: No group assigned');
      return '/waiting-for-assignment';
    }

    if (role == 'teacher') return '/teacher-dashboard';
    if (role == 'student') return '/student-dashboard';

    print('⚠️ _nextRoute: Unknown role, defaulting to /student-dashboard');
    return '/student-dashboard';
  } catch (e) {
    print('❌ _nextRoute: Error checking profile: $e');
    return '/login';
  }
}
```

---

## 📁 ARCHIVO 7: lib/video_call/whiteboard/whiteboard_service.dart

### ✏️ CAMBIO 8: Mejorar dispose de whiteboard service

**Ubicación:** Método `dispose()` (alrededor de línea 120)

**Antes (INCORRECTO):**
```dart
void dispose() {
  _channel.unsubscribe();
}
```

**Después (CORRECTO):**
```dart
Future<void> dispose() async {
  try {
    print('🧹 [WHITEBOARD_SERVICE] Desuscribiendo del canal...');
    await _channel.unsubscribe();
    print('✅ [WHITEBOARD_SERVICE] Canal cerrado correctamente');
  } catch (e) {
    print('⚠️ [WHITEBOARD_SERVICE] Error unsubscribing: $e');
  }
}
```

---

## 🎯 ORDEN DE APLICACIÓN

1. **Primero:** Cambio 1 (video_call_screen dispose)
2. **Segundo:** Cambio 2 (validación en broadcast)
3. **Tercero:** Cambio 3 (controller dispose)
4. **Cuarto:** Cambio 4 (session service error handling)
5. **Quinto:** Cambio 5 (API service validation)
6. **Sexto:** Cambio 6 (retry logic)
7. **Séptimo:** Cambio 7 (validar usuario activo)
8. **Octavo:** Cambio 8 (whiteboard dispose)

---

## ✅ DESPUÉS DE APLICAR

**Hacer pruebas:**
```bash
# 1. Test básico: Login y logout
flutter run

# 2. Test comunicación: 
#    - Estudiante entra a waiting room
#    - Maestro admite
#    - Verifica que estados cambien

# 3. Test limpieza:
#    - Monitorea memoria en DevTools
#    - Verifica que no hay memory leaks
#    - Cierra pantallas y verifica cleanup

# 4. Test error handling:
#    - Desconecta internet a mitad de operación
#    - Verifica que reintentos funcionen
#    - Verifica que errores se muestren al usuario
```

---

## 📊 RESUMEN DE CAMBIOS

| Archivo | Cambios | Líneas | Tiempo |
|---------|---------|--------|--------|
| video_call_screen.dart | 2 | 50 | 15 min |
| video_call_controller.dart | 1 | 35 | 10 min |
| session_service.dart | 1 | 40 | 15 min |
| api_service.dart | 1 | 25 | 5 min |
| student_waiting_room_screen.dart | 1 | 60 | 20 min |
| main.dart | 1 | 35 | 10 min |
| whiteboard_service.dart | 1 | 15 | 5 min |

**Total:** 8 cambios, ~260 líneas, ~80 minutos

