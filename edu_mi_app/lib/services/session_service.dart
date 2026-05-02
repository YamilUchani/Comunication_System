import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class SessionService {
  final SupabaseClient _supabase = Supabase.instance.client;
  Timer? _heartbeatTimer;

  // Iniciar latido (Heartbeat) - Llamar al unirse
  // ⏱️ OPTIMIZADO: 90 segundos en lugar de 45 para reducir carga en Supabase
  // Una sesión activa no necesita verificarse cada 45s
  void startHeartbeat(String sessionId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 90), (
      timer,
    ) async {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        stopHeartbeat();
        return;
      }
      try {
        await _supabase.rpc(
          'update_heartbeat',
          params: {'p_session_id': sessionId},
        );
      } catch (e) {
        print('Error en heartbeat: $e');
      }
    });
  }

  // Detener latido - Llamar al salir/dispose
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // Unirse a la sesión (Solo presencia en DB)
  Future<void> joinSession({
    required String sessionId,
    required String userName,
    required String role,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('session_participants').upsert({
      'session_id': sessionId,
      'user_id': user.id,
      'user_name': userName,
      'role': role,
      'status':
          (role == AppConstants.roleTeacher || role == AppConstants.roleAdmin)
          ? AppConstants.sessionStatusActive
          : AppConstants
                .sessionStatusPresent, // Teacher/Admin active, student present
      'updated_at': DateTime.now().toIso8601String(),
      'last_seen': DateTime.now().toIso8601String(),
    }, onConflict: 'session_id, user_id');

    startHeartbeat(sessionId); // Iniciar latido automáticamente
  }

  // Solicitar hablar (Cambiar estado a requesting)
  Future<void> requestToSpeak(String sessionId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('session_participants')
        .update({
          'status': AppConstants.sessionStatusRequesting,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('session_id', sessionId)
        .eq('user_id', user.id);
  }

  // Aceptar usuario (Cambiar estado a active)
  Future<void> acceptUser(String sessionId, String userId) async {
    try {
      print('[SESSION_SERVICE] acceptUser INICIADO - sessionId=$sessionId, userId=$userId');

      // 1) Intentar UPDATE primero
      print('[SESSION_SERVICE] Intentando UPDATE...');
      var updateResult = await _supabase
          .from('session_participants')
          .update({
            'status': AppConstants.sessionStatusActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('session_id', sessionId)
          .eq('user_id', userId)
          .select();

      print('[SESSION_SERVICE] UPDATE result: ${updateResult.length} filas actualizadas');

      // 2) Si UPDATE no afectó ninguna fila, hacer INSERT
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
        
        print('[SESSION_SERVICE] Insertando: userName=$userName, userRole=$userRole');
        
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

  // Sacar de videollamada (Cambiar estado a present)
  Future<void> downgradeToLobby(String sessionId, String userId) async {
    await _supabase
        .from('session_participants')
        .update({
          'status': AppConstants.sessionStatusPresent,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('session_id', sessionId)
        .eq('user_id', userId);
  }

  // Expulsar usuario (Eliminar registro de participante)
  Future<void> kickUser(String sessionId, String userId) async {
    print('[SESSION_SERVICE] kickUser INICIADO - sessionId=$sessionId, userId=$userId');
    
    try {
      // Usar la MISMA lógica que removeAllParticipants pero específico
      print('[SESSION_SERVICE] Ejecutando DELETE directo...');
      
      final deleteResult = await _supabase
          .from('session_participants')
          .delete()
          .eq('session_id', sessionId)
          .eq('user_id', userId);
      
      print('[SESSION_SERVICE] DELETE completado. Resultado: $deleteResult filas afectadas');
      
      // Forzar una re-fetch para confirmar que fue eliminado
      await Future.delayed(const Duration(milliseconds: 100));
      
      final remainingRows = await _supabase
          .from('session_participants')
          .select('count')
          .eq('session_id', sessionId)
          .eq('user_id', userId);
      
      print('[SESSION_SERVICE] kickUser ✅ completado exitosamente');
    } catch (e) {
      print('[SESSION_SERVICE] ❌ Error en kickUser: $e');
      rethrow;
    }
  }

  // Salir de la sesión (Eliminar registro)
  Future<void> leaveSession(String sessionId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('session_participants')
        .delete()
        .eq('session_id', sessionId)
        .eq('user_id', user.id);

    stopHeartbeat(); // Detener latido
  }

  // Limpiar toda la sala (Admin/Teacher) - Elimina a todos MENOS al que llama
  Future<void> removeAllParticipants(String sessionId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('session_participants')
        .delete()
        .eq('session_id', sessionId)
        .neq('user_id', user.id); // No borrarse a sí mismo
  }

  // Stream de participantes para la lista en tiempo real
  // Obtener fecha de inicio de la sesión
  Future<DateTime?> fetchSessionStartTime(String channelName) async {
    try {
      final data = await _supabase
          .from('meetings')
          .select('created_at')
          .eq('channel_name', channelName)
          .maybeSingle();

      if (data != null && data['created_at'] != null) {
        return DateTime.parse(data['created_at']).toLocal();
      }
    } catch (e) {
      print('Error fetching session start time: $e');
    }
    return null;
  }

  // Finalizar sesión (Eliminar reunión y sacar a todos)
  Future<void> endSession(String channelName) async {
    try {
      // 1. Obtener ID de la reunión
      final meeting = await _supabase
          .from('meetings')
          .select('id')
          .eq('channel_name', channelName)
          .maybeSingle();

      if (meeting != null) {
        final meetingId = meeting['id'];

        // 2. Eliminar participantes de sesión
        await _supabase
            .from('session_participants')
            .delete()
            .eq('session_id', channelName);

        // 3. Soft delete: marcar reunión como inactiva en vez de eliminar
        await _supabase
            .from('meetings')
            .update({
              'is_active': false,
              'ended_at': DateTime.now().toIso8601String(),
            })
            .eq('id', meetingId);
      }
    } catch (e) {
      print('Error ending session: $e');
    }
  }

  /// Obtiene la lista actual de participantes (una sola vez). Útil para estado inicial cuando el maestro entra después del estudiante.
  Future<List<Map<String, dynamic>>> getParticipants(String sessionId) async {
    final res = await _supabase
        .from('session_participants')
        .select('*')
        .eq('session_id', sessionId);
    return List<Map<String, dynamic>>.from(res);
  }

  Stream<List<Map<String, dynamic>>> getParticipantsStream(String sessionId) {
    return _supabase
        .from('session_participants')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }
}
