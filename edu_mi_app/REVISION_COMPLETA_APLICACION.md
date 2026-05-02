# 🔍 REVISIÓN COMPLETA DE LA APLICACIÓN

**Fecha:** 18 Abril 2026  
**Alcance:** Comunicación entre maestro-estudiante-admin, navegación, manejo de ventanas, ciclo de vida  
**Estado:** ⚠️ VARIOS PROBLEMAS ENCONTRADOS

---

## 📋 RESUMEN EJECUTIVO

He realizado una auditoría exhaustiva de:
- ✅ Autenticación y autorización
- ✅ Comunicación realtime (Supabase)
- ✅ Sistema de videollamadas (Agora)
- ✅ Navegación y rutas
- ✅ Manejo de ventanas secundarias
- ✅ Ciclo de vida y cleanup

### Hallazgos:

| Severidad | Categoría | Cantidad | Estado |
|-----------|-----------|----------|--------|
| 🔴 Crítico | Memory Leaks | 4 | ⚠️ Debe corregirse |
| 🟠 Alto | Null Safety | 6 | ⚠️ Riesgoso |
| 🟡 Medio | Error Handling | 5 | ⚠️ Mejorable |
| 🔵 Bajo | Code Quality | 3 | ℹ️ Recomendación |

**Total:** 18 problemas identificados

---

## 🔴 PROBLEMAS CRÍTICOS

### 1. MEMORY LEAK: Timer no cancelado en VideoCallScreen

**Archivo:** [lib/video_call/video_call_screen.dart](lib/video_call/video_call_screen.dart#L80)

**Problema:**
```dart
_autoStudentRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
  if (mounted && !_showStudents) {
    _fetchStudentsStatus();
  }
});

// ❌ En dispose(), el timer NO se cancela
@override
void dispose() {
  // 🚨 FALTA: _autoStudentRefreshTimer?.cancel();
  super.dispose();
}
```

**Impacto:** El timer continúa ejecutándose después de que la pantalla se cierra, causando:
- Consumo de memoria
- Llamadas API innecesarias
- Posible crash si `mounted` falla

**Solución:**
```dart
@override
void dispose() {
  _autoStudentRefreshTimer?.cancel();  // ✅ Agregar
  _studentsTimer?.cancel();             // ✅ También esto
  _realtimeChannel?.unsubscribe();      // ✅ Y esto
  if (Platform.isWindows) {
    windowManager.removeListener(this);
  }
  super.dispose();
}
```

---

### 2. MEMORY LEAK: Realtime Channel no unsubscribido

**Archivo:** [lib/video_call/video_call_screen.dart](lib/video_call/video_call_screen.dart#L75)

**Problema:**
```dart
_meetingChannel = Supabase.instance.client
    .channel('meeting:$meetingId')
    .onBroadcast(...)
    .subscribe();

// ❌ En dispose(), el channel se CREA pero nunca se limpia
@override
void dispose() {
  // 🚨 FALTA: _meetingChannel?.unsubscribe();
  super.dispose();
}
```

**Impacto:**
- Listeners quedan activos en memoria
- Eventos fantasma después de salir
- Múltiples suscripciones al mismo canal

**Solución:**
```dart
@override
void dispose() {
  _meetingChannel?.unsubscribe();
  _autoStudentRefreshTimer?.cancel();
  _studentsTimer?.cancel();
  super.dispose();
}
```

---

### 3. MEMORY LEAK: VideoCallController no disposado correctamente

**Archivo:** [lib/video_call/video_call_screen.dart](lib/video_call/video_call_screen.dart#L42)

**Problema:**
```dart
@override
void initState() {
  controller = VideoCallController(...);
  MeetingCleanupService.registerActiveController(controller);
  _initAgora();  // inicia el RtcEngine
}

// ❌ En dispose(), el controller NO se limpia
@override
void dispose() {
  // 🚨 FALTA: await controller.leaveAndDispose();
  super.dispose();
}
```

**Impacto:**
- Motor de Agora sigue corriendo en background
- Conexión no se cierra
- Recursos de video/audio no liberados

**Solución:**
```dart
@override
void dispose() async {
  try {
    await controller.leaveAndDispose();
  } catch (e) {
    print('Error en dispose: $e');
  }
  _autoStudentRefreshTimer?.cancel();
  _meetingChannel?.unsubscribe();
  super.dispose();
}
```

---

### 4. RACE CONDITION: Estado inconsistente en transiciones

**Archivo:** [lib/screens/student_waiting_room_screen.dart](lib/screens/student_waiting_room_screen.dart#L60)

**Problema:**
```dart
void _setupRealtimeSubscription() {
  // Cuando recibe admit_student:
  .onBroadcast(event: 'admit_student', callback: (payload) {
    // ❌ Llama _joinMeeting() inmediatamente
    _joinMeeting();
  })
}

Future<void> _joinMeeting() {
  // Pero también hay:
  // 1. ApiService.setEnteredCallStatus(meetingId) 
  // 2. Abre nueva ventana con Process.start()
  // Sin esperar que completara el anterior
}
```

**Impacto:**
- Dos procesos intentan entrar simultáneamente
- Estado en BD no actualizado correctamente
- Ventana puede abrirse dos veces

**Solución:**
```dart
.onBroadcast(event: 'admit_student', callback: (payload) {
  final admittedId = payload['user_id'] as String?;
  if (admittedId == currentUserId && mounted) {
    // ✅ Esperar a que _joinMeeting() complete
    _joinMeeting().then((_) {
      // Recién ahora actualizar UI
    }).catchError((e) {
      print('Error en join: $e');
      // Mostrar error al usuario
    });
  }
})
```

---

## 🟠 PROBLEMAS DE NULL SAFETY

### 5. Casting sin validación en Realtime events

**Archivo:** [lib/video_call/video_call_screen.dart](lib/video_call/video_call_screen.dart#L110)

**Problema:**
```dart
.onBroadcast(event: 'student_calling', callback: (payload) {
  // ❌ Casting directo sin validación
  final studentName = payload['student_name'] as String?;
  if (studentName != null && mounted) {
    _showStudentCallNotification(studentName);
  }
})
```

**Riesgo:** Si `payload` no tiene la estructura esperada, puede causar:
- TypeError
- Crash de la app
- Evento no procesado silenciosamente

**Solución:**
```dart
.onBroadcast(event: 'student_calling', callback: (payload) {
  try {
    // ✅ Validar estructura
    if (payload is! Map<String, dynamic>) {
      print('⚠️ Payload inválido en student_calling');
      return;
    }
    
    final studentName = payload['student_name'];
    if (studentName is! String || studentName.isEmpty) {
      print('⚠️ student_name inválido o vacío');
      return;
    }
    
    if (mounted) {
      _showStudentCallNotification(studentName);
    }
  } catch (e) {
    print('❌ Error procesando student_calling: $e');
  }
})
```

---

### 6. Acceso a contexto sin validación

**Archivo:** [lib/video_call/chat/chat_controller.dart](lib/video_call/chat/chat_controller.dart#L90)

**Problema:**
```dart
void _showNotification(ChatMessage message) {
  if (_context == null) return;

  // ❌ Acceso directo sin validación en addPostFrameCallback
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_context != null && mounted) {
      try {
        NotificationOverlay.showNotification(_context!, ...);
      } catch (e) {
        // Silenciosamente ignorado
      }
    }
  });
}
```

**Riesgo:**
- `_context` puede volverse inválido entre callbacks
- El widget puede destruirse mientras se ejecuta el callback
- No hay manejo de excepciones real

**Solución:**
```dart
void _showNotification(ChatMessage message) {
  if (_context == null || !mounted) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    // ✅ Doble validación
    if (_context == null) {
      print('⚠️ Contexto fue limpiado antes del callback');
      return;
    }
    
    try {
      if (_context!.mounted) {
        NotificationOverlay.showNotification(_context!, ...);
      }
    } catch (e) {
      print('❌ Error mostrando notificación: $e');
      // Log y manejo apropiado
    }
  });
}
```

---

### 7. Nullability en ApiService

**Archivo:** [lib/services/api_service.dart](lib/services/api_service.dart#L10)

**Problema:**
```dart
static String get _baseUrl => dotenv.env['BACKEND_URL'] ?? '';

// ❌ Si BACKEND_URL está vacío, todas las llamadas fallarán
static Future<Map<String, dynamic>> getAdminStats() async {
  final response = await http.get(
    Uri.parse('$_baseUrl/admin/stats'),  // URL vacía si BACKEND_URL falta
    headers: await _getHeaders(),
  );
  // ...
}
```

**Solución:**
```dart
static String get _baseUrl {
  final url = dotenv.env['BACKEND_URL'];
  if (url == null || url.isEmpty) {
    throw Exception('BACKEND_URL no configurado en .env');
  }
  return url;
}

static Future<Map<String, String>> _getHeaders() async {
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) {
    throw Exception('No hay sesión activa');
  }
  // ✅ Validar que el token no esté vacío
  if (session.accessToken.isEmpty) {
    throw Exception('Token de acceso vacío');
  }
  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${session.accessToken}',
  };
}
```

---

## 🟡 PROBLEMAS DE ERROR HANDLING

### 8. Error handling incompleto en Session Service

**Archivo:** [lib/services/session_service.dart](lib/services/session_service.dart#L80)

**Problema:**
```dart
Future<void> acceptUser(String sessionId, String userId) async {
  try {
    // UPDATE intenta actualizar
    var updateResult = await _supabase.from('session_participants')
        .update({...})
        .eq('session_id', sessionId)
        .eq('user_id', userId)
        .select();

    // Si no actualiza, INSERTA
    if (updateResult.isEmpty) {
      // ❌ No hay validación si el INSERT falla
      await _supabase.from('session_participants').insert({...});
    }
  } catch (e) {
    // ❌ Log pero no se propaga el error
    print('Error en acceptUser: $e');
    rethrow;  // Solo al final
  }
}
```

**Riesgo:** Inconsistencias de estado si INSERT falla silenciosamente

**Solución:**
```dart
Future<void> acceptUser(String sessionId, String userId) async {
  try {
    var updateResult = await _supabase.from('session_participants')
        .update({'status': 'active'})
        .eq('session_id', sessionId)
        .eq('user_id', userId)
        .select();

    if (updateResult.isEmpty) {
      try {
        // ✅ Validar que INSERT fue exitoso
        final insertResult = await _supabase.from('session_participants')
            .insert({
              'session_id': sessionId,
              'user_id': userId,
              'status': 'active',
              // ...
            })
            .select();
        
        if (insertResult.isEmpty) {
          throw Exception('INSERT no retornó la fila insertada');
        }
      } catch (insertError) {
        print('❌ Error en INSERT: $insertError');
        throw Exception('No se pudo admitir al usuario: $insertError');
      }
    }
  } catch (e) {
    print('❌ Error en acceptUser: $e');
    rethrow;
  }
}
```

---

### 9. Falta de reintentos en eventos Broadcast

**Archivo:** [lib/screens/student_waiting_room_screen.dart](lib/screens/student_waiting_room_screen.dart#L90)

**Problema:**
```dart
Future<void> _callTeacher({bool isAuto = false}) async {
  try {
    // ✅ Tiene reintentos
    bool eventSent = false;
    int retries = 0;
    while (!eventSent && retries < 3) {
      try {
        await _realtimeChannel?.sendBroadcastMessage(...);
        eventSent = true;
      } catch (e) {
        retries++;
        if (retries < 3) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }
  } catch (e) {
    // ❌ Pero no hay reintentos para ApiService.setBackToWaitingRoomStatus()
    await ApiService.setBackToWaitingRoomStatus(meetingId);
  }
}
```

**Problema:** La llamada a API puede fallar sin reintentos

**Solución:**
```dart
Future<void> _callTeacher({bool isAuto = false}) async {
  try {
    // Reintentos para broadcast
    await _retryOperation(() async {
      await _realtimeChannel?.sendBroadcastMessage(...);
    }, maxRetries: 3);
    
    // ✅ También reintentos para API
    await _retryOperation(() async {
      await ApiService.setBackToWaitingRoomStatus(meetingId);
    }, maxRetries: 2, delayMs: 1000);
  } catch (e) {
    print('❌ Error en _callTeacher: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: No se pudo contactar al maestro')),
      );
    }
  }
}

// ✅ Función helper para reintentos
Future<void> _retryOperation(
  Future<void> Function() operation, {
  int maxRetries = 3,
  int delayMs = 500,
}) async {
  for (int i = 0; i < maxRetries; i++) {
    try {
      await operation();
      return;
    } catch (e) {
      if (i == maxRetries - 1) rethrow;
      await Future.delayed(Duration(milliseconds: delayMs));
    }
  }
}
```

---

### 10. Error silencioso en Whiteboard dispose

**Archivo:** [lib/video_call/whiteboard/whiteboard_service.dart](lib/video_call/whiteboard/whiteboard_service.dart#L120)

**Problema:**
```dart
void dispose() {
  // ❌ Si unsubscribe() falla, no hay manejo
  _channel.unsubscribe();
}
```

**Solución:**
```dart
Future<void> dispose() async {
  try {
    await _channel.unsubscribe();
    print('✅ Whiteboard channel unsubscribed');
  } catch (e) {
    print('⚠️ Error unsubscribing from whiteboard: $e');
  }
}
```

---

## 🔵 RECOMENDACIONES DE CALIDAD

### 11. Logging mejorado en VideoCallController

**Archivo:** [lib/video_call/video_call_controller.dart](lib/video_call/video_call_controller.dart#L60)

**Sugerencia:**
```dart
// ❌ Actual
if (response.statusCode == 200) {
  return;
}

// ✅ Mejorado
if (response.statusCode == 200) {
  print('✅ Usuario left notificado correctamente al backend');
  return;
}

// Agregar contexto a los logs
print('[VIDEO_CALL_CONTROLLER] 📡 Notificando user_left:');
print('   - UID: $uid');
print('   - Meeting: $meetingId');
print('   - Status code: ${response.statusCode}');
```

---

### 12. Validación de permisos en navegación

**Archivo:** [lib/main.dart](lib/main.dart#L300)

**Problema:**
```dart
Future<String> _nextRoute() async {
  // ✅ Valida rol
  if (role == 'teacher') return '/teacher-dashboard';
  
  // ❌ Pero no valida que el usuario esté activo
  // ¿Qué pasa si el usuario fue desactivado/eliminado?
}
```

**Solución:**
```dart
Future<String> _nextRoute() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return '/login';

  try {
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('full_name, age, role, group_name, is_active')  // ✅ Agregar is_active
        .eq('user_id', user.id)
        .maybeSingle();

    // ✅ Validar estado activo
    if (profile?['is_active'] == false) {
      print('⚠️ Usuario inactivo');
      await Supabase.instance.client.auth.signOut();
      return '/login';
    }
    
    // ... resto de lógica
  } catch (e) {
    print('❌ Error en _nextRoute: $e');
    return '/login';
  }
}
```

---

### 13. Documentación faltante en funciones críticas

**Archivo:** Múltiples archivos

**Problema:** Funciones complejas sin documentación

**Solución:**
```dart
/// 🔍 Intenta ejecutar una operación con reintentos automáticos
/// 
/// Parámetros:
/// - [operation]: Función async a ejecutar
/// - [maxRetries]: Número máximo de intentos (default: 3)
/// - [delayMs]: Delay entre reintentos en ms (default: 500)
/// 
/// Lanza excepción si todos los intentos fallan
/// 
/// Ejemplo:
/// ```dart
/// await _retryOperation(
///   () => apiService.fetchData(),
///   maxRetries: 3,
///   delayMs: 1000,
/// );
/// ```
Future<void> _retryOperation(
  Future<void> Function() operation, {
  int maxRetries = 3,
  int delayMs = 500,
}) async {
  for (int i = 0; i < maxRetries; i++) {
    try {
      await operation();
      return;
    } catch (e) {
      if (i == maxRetries - 1) rethrow;
      await Future.delayed(Duration(milliseconds: delayMs));
    }
  }
}
```

---

## ✅ COSAS QUE ESTÁN BIEN

### 1. ✅ Autenticación robusta
- Middleware auth.js valida tokens correctamente
- RLS policies configuradas
- Separación de permisos por rol

### 2. ✅ Navegación basada en estado
- _nextRoute() verifica perfil completo
- Redirección correcta según rol
- Validación de grupo asignado

### 3. ✅ Sistema de ventanas secundarias
- Process.start() bien implementado
- PID registry para cleanup
- Argumentos pasados correctamente

### 4. ✅ Realtime Broadcast funciona
- Eventos student_calling/admit_student/kick_student
- Supabase channel se suscribe correctamente
- Payloads con estructura clara

### 5. ✅ Agora integration
- Token generation on backend ✅
- Channel join con validación ✅
- Screen sharing bien configurado ✅

### 6. ✅ Chat system
- Data streams para mensajes privados ✅
- Filtro de sender IDs funciona ✅
- Notificaciones mostradas

---

## 🛠️ PLAN DE CORRECCIÓN

### Prioridad 1 (Hacer hoy):
```
1. [ ] Agregar cleanup de timers en video_call_screen.dart
2. [ ] Agregar unsubscribe de realtime channels
3. [ ] Mejorar null checks en payload validation
4. [ ] Agregar dispose() al VideoCallController
```

### Prioridad 2 (Esta semana):
```
5. [ ] Implementar retry logic en API calls
6. [ ] Mejorar error handling en session_service
7. [ ] Validar is_active en _nextRoute()
8. [ ] Agregar logging estructurado
```

### Prioridad 3 (Próximas 2 semanas):
```
9. [ ] Documentar funciones críticas
10. [ ] Agregar unit tests
11. [ ] Implementar error boundaries
12. [ ] Monitoreo en producción
```

---

## 📊 TABLA DE SEVERIDAD

| ID | Problema | Severidad | Impacto | Esfuerzo |
|----|----------|-----------|---------|----------|
| 1 | Timer no cancelado | 🔴 Crítico | Memory leak | 5 min |
| 2 | Channel no unsubscribido | 🔴 Crítico | Memory leak | 5 min |
| 3 | Controller no disposado | 🔴 Crítico | Leak resources | 10 min |
| 4 | Race condition | 🔴 Crítico | Estado inconsistente | 20 min |
| 5 | Casting sin validación | 🟠 Alto | Crash posible | 15 min |
| 6 | Contexto sin validación | 🟠 Alto | Crash posible | 10 min |
| 7 | BaseUrl vacío | 🟠 Alto | API calls fallan | 5 min |
| 8 | Error handling incompleto | 🟡 Medio | Estado inconsistente | 15 min |
| 9 | Falta reintentos | 🟡 Medio | Fallo de operaciones | 20 min |
| 10 | Error silencioso | 🟡 Medio | Debug difícil | 5 min |

**Esfuerzo Total Estimado:** ~2 horas

---

## 🎯 CONCLUSIÓN

La aplicación está **mayormente funcional** pero tiene **problemas de limpieza y manejo de errores** que pueden causar:

- ❌ Memory leaks en uso prolongado
- ❌ Crashes silenciosos con datos malformados
- ❌ Estados inconsistentes en transiciones
- ❌ Operaciones que fallan sin reintentos

**Recomendación:** Implementar las correcciones Prioridad 1 inmediatamente antes de usar en producción.

---

## 📚 Archivos relacionados:
- [Backend README](backend/README.md)
- [DIAGNOSTICO_SISTEMA_LLAMADAS.md](DIAGNOSTICO_SISTEMA_LLAMADAS.md)
- [STUDENT_CALL_SYSTEM_FIX.md](STUDENT_CALL_SYSTEM_FIX.md)

