// Servicio centralizado para limpiar la reunión cuando el usuario cierra sesión
// o sale de la aplicación

import 'dart:io';
import 'package:flutter/material.dart';
import '../video_call/video_call_controller.dart';
import '../main.dart' as main_module;

/// 🔄 Servicio para limpiar la reunión activa
/// Este servicio se encarga de:
/// 1. Detectar si hay una reunión activa
/// 2. Desconectar del Agora channel
/// 3. Limpiar recursos
/// 4. Cerrar la ventana secundaria si está abierta
class MeetingCleanupService {
  static final MeetingCleanupService _instance = MeetingCleanupService._internal();
  
  factory MeetingCleanupService() {
    return _instance;
  }
  
  MeetingCleanupService._internal();

  // Referencia al controlador activo (si hay uno)
  static VideoCallController? _activeController;

  /// Registra el controlador activo
  static void registerActiveController(VideoCallController controller) {
    _activeController = controller;
    print('✅ [MeetingCleanup] Controlador registrado para limpieza');
  }

  /// Desregistra el controlador activo
  static void unregisterActiveController() {
    _activeController = null;
    print('✅ [MeetingCleanup] Controlador desregistrado');
  }

  /// Limpia la reunión activa
  /// Se llama cuando:
  /// - El usuario presiona el botón de logout
  /// - El usuario cierra la ventana
  /// - El usuario sale mediante back button
  /// - El sistema solicita salida (didRequestAppExit)
  static Future<void> cleanupActiveMeeting({
    bool closeWindow = false,
  }) async {
    print('🔄 [MeetingCleanup] Iniciando limpieza de reunión...');
    
    if (_activeController == null) {
      print('ℹ️ [MeetingCleanup] No hay reunión activa para limpiar');
      return;
    }

    try {
      print('⏳ [MeetingCleanup] Desconectando de Agora...');
      await _activeController!.leaveAndDispose();
      print('✅ [MeetingCleanup] Desconexión completada');
      
      // Esperar un poco para que se procese
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Si es ventana secundaria y se solicita cerrar, hacerlo
      if (closeWindow && main_module.isSecondaryWindow) {
        print('🪟 [MeetingCleanup] Cerrando ventana secundaria...');
        await Future.delayed(const Duration(milliseconds: 200));
        exit(0);
      }
    } catch (e) {
      print('❌ [MeetingCleanup] Error durante la limpieza: $e');
      rethrow;
    }
  }

  /// Obtiene el estado de la reunión
  static bool hasActiveMeeting() {
    return _activeController != null;
  }

  /// Obtiene info de la reunión activa
  static String? getActiveMeetingChannel() {
    return _activeController?.channelName;
  }
}

/// 📋 LISTA COMPLETA DE PUNTOS DE SALIDA DEL USUARIO
/// ================================================
///
/// 1. LOGOUT EN DASHBOARDS (3 puntos)
///    ✅ student_dashboard.dart - IconButton logout (línea 105-110)
///    ✅ teacher_dashboard.dart - IconButton logout (línea 129-134)
///    ✅ admin_dashboard.dart - IconButton logout (línea 72-76)
///    ✅ home_screen.dart - _signOut() (línea 40-41)
///    ✅ waiting_for_assignment_screen.dart - logout (línea 274, 281)
///
/// 2. SALIDA DE VIDEOLLAMADA (2 puntos)
///    ✅ student_video_call_screen.dart:
///       - _exitMeeting() (línea 258)
///       - didRequestAppExit() (línea 73)
///       - WillPopScope (línea 289)
///    ✅ video_call_screen.dart (Maestro/Admin):
///       - _exitMeeting() (línea ~165)
///       - didRequestAppExit() (línea 64)
///       - Control bar exit button
///
/// 3. CIERRE DE VENTANA (1 punto)
///    ✅ main.dart - didRequestAppExit() (línea 326)
///    ✅ Windows: Alt+F4, botón X de ventana
///
/// 4. DESCONEXIÓN/TIMEOUT (Manejado por Agora)
///    ℹ️ Timeout de conexión - Agora desconecta automáticamente
///    ℹ️ Pérdida de red - Agora detecta y notifica
///
/// 5. NAVEGACIÓN LEJOS DE VIDEOLLAMADA
///    ✅ Presionar atrás en WillPopScope
///    ✅ Navigator.pop/pushReplacement
///
/// IMPLEMENTACIÓN REQUERIDA:
/// - Registrar el controlador al iniciar videollamada
/// - Llamar a cleanupActiveMeeting() en logout
/// - Llamar a cleanupActiveMeeting(closeWindow: true) al cerrar
/// - Desregistrar al finalizar videollamada
