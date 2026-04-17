// Archivo: video_call_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class VideoCallController {
  final String channelName;
  final String token;
  final String? meetingId; // ID de la reunión para heartbeat
  final String? authToken; // Token de autenticación para heartbeat
  final ValueNotifier<bool> localUserJoined = ValueNotifier(false);
  final ValueNotifier<bool> isAudioMuted = ValueNotifier(false);
  final ValueNotifier<bool> isVideoMuted = ValueNotifier(false);
  final ValueNotifier<Set<int>> remoteUids = ValueNotifier({});
  final ValueNotifier<Set<int>> remoteScreenShareUids = ValueNotifier({});
  final ValueNotifier<bool> otherUserLeft = ValueNotifier(false); // 🔔 Notifica cuando otro usuario se va

  late RtcEngine _engine;
  RtcEngine get engine => _engine;
  int _localUid = 0;
  int get localUid => _localUid;
  final int? _providedUid;
  Timer? _joinTimeoutTimer;
  bool _isCameraDisabledByNetwork = false; // 📡 Cámara desactivada por mala red
  bool _isNetworkQualityLow = false; // 📡 Rastrear estado de red
  bool _isDisposed = false; // 🧹 Flag para evitar doble-dispose

  VideoCallController({
    required this.channelName,
    required this.token,
    int? uid,
    this.meetingId,
    this.authToken,
  }) : _providedUid = uid;

  Future<void> init() async {
    try {
      final appId = dotenv.env['AGORA_APP_ID'] ?? '';
      if (appId.isEmpty) {
        throw 'AGORA_APP_ID no está configurado en el archivo .env';
      }

      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(appId: appId));

      _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      _engine.enableVideo();
      _engine.startPreview();

      final uid = _providedUid ?? 0;
      _localUid = uid;

      print('🚀 Uniéndose al canal: $channelName con UID: $uid');

      final completer = Completer<void>();

      // ✅ Iniciar timer de timeout de 15 segundos
      _joinTimeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!completer.isCompleted) {
          print('❌ TIMEOUT: No se pudo unir al canal tras 15 segundos.');
          completer.completeError('No se pudo conectar con el servidor de video (Timeout 15s)');
        }
      });

      // ✅ UN SOLO registro de eventos consolidado
      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            _joinTimeoutTimer?.cancel();
            if (connection.localUid != null && connection.localUid != 0) {
              _localUid = connection.localUid!;
            }
            localUserJoined.value = true;
            if (!completer.isCompleted) completer.complete();
            print('[EVENT] onJoinChannelSuccess: uid=${connection.localUid}');
          },
          onError: (err, msg) {
            print('❌ Agora Error: $err, $msg');
            if (!completer.isCompleted) completer.completeError('Error de Agora: $err - $msg');
          },
          onUserJoined: (connection, uid, elapsed) {
            final currentUids = Set<int>.from(remoteUids.value)..add(uid);
            remoteUids.value = currentUids;
            print('[EVENT] onUserJoined: uid=$uid');
          },
          onUserOffline: (connection, uid, reason) {
            print('🚪 [DESCONEXION] onUserOffline uid=$uid razón=${reason.name}');
            
            // Notificar al backend
            _notifyUserLeft(uid);
            
            final currentUids = Set<int>.from(remoteUids.value)..remove(uid);
            remoteUids.value = currentUids;

            if (remoteScreenShareUids.value.contains(uid)) {
              removeRemoteScreenShareUid(uid);
            }
          },
          onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
            print('[EVENT] onRemoteVideoStateChanged: uid=$remoteUid, state=$state, reason=$reason');
          },
          onVideoSizeChanged: (connection, sourceType, uid, width, height, rotation) {
            if (sourceType == VideoSourceType.videoSourceScreen) {
              addRemoteScreenShareUid(uid);
            } else if (sourceType == VideoSourceType.videoSourceCamera ||
                sourceType == VideoSourceType.videoSourceCameraPrimary) {
              removeRemoteScreenShareUid(uid);
            }
          },
          onConnectionStateChanged: (connection, state, reason) {
            print('[EVENT] onConnectionStateChanged: state=$state, reason=$reason');
          },
          onNetworkQuality: (connection, uid, txQuality, rxQuality) {
            if (uid == 0) {
              final isNetworkBad = txQuality.index >= 4;
              if (isNetworkBad && !_isNetworkQualityLow) {
                _isNetworkQualityLow = true;
                _isCameraDisabledByNetwork = true;
                // Solo silenciamos el stream, no lo desactivamos (para no interferir con el toggle manual)
                _engine.muteLocalVideoStream(true);
                print('⚠️ Red mala (${txQuality.name}), cámara silenciada');
              } else if (!isNetworkBad && _isNetworkQualityLow) {
                _isNetworkQualityLow = false;
                _isCameraDisabledByNetwork = false;
                // Solo reactivar si el usuario no lo muted manualmente
                if (!isVideoMuted.value) {
                  _engine.muteLocalVideoStream(false);
                }
                print('✅ Red recuperada (${txQuality.name}), cámara reactivada');
              }
            }
          },
        ),
      );

      await _engine.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
        ),
      );

      return completer.future;
    } catch (e) {
      debugPrint('Error al inicializar Agora: $e');
      _joinTimeoutTimer?.cancel();
      rethrow;
    }
  }

  Future<void> toggleAudio() async {
    final newMuteState = !isAudioMuted.value;
    // enableLocalAudio(false) detiene el track completamente (más confiable que mute)
    await _engine.enableLocalAudio(!newMuteState);
    isAudioMuted.value = newMuteState;
    print('🎤 Audio ${newMuteState ? "desactivado" : "activado"}');
  }

  Future<void> toggleVideo() async {
    final newMuteState = !isVideoMuted.value;
    // enableLocalVideo(false) detiene el track y el preview (más confiable que mute)
    await _engine.enableLocalVideo(!newMuteState);
    isVideoMuted.value = newMuteState;
    print('📷 Video ${newMuteState ? "desactivado" : "activado"}');
  }

  // ❤️ NO HEARTBEAT: Usar solo eventos nativos de Agora
  // onUserOffline se dispara automáticamente cuando alguien se desconecta
  // onRemoteVideoStateChanged detecta cuando video está congelado/detenido
  // Esto es mucho más eficiente que polling cada 3 segundos
  
  Future<void> _notifyUserLeft(int uid) async {
    // Notificación única cuando otro usuario se va
    if (meetingId == null) {
      print('   ⚠️ meetingId es null, no notificando');
      return;
    }
    
    try {
      final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';
      String? accessToken = authToken;
      if (accessToken == null) {
        try {
          final session = Supabase.instance.client.auth.currentSession;
          accessToken = session?.accessToken;
        } catch (e) {
          print('   ⚠️ Error obteniendo accessToken de Supabase: $e');
          return;
        }
      }
      
      if (accessToken == null) {
        print('   ⚠️ No hay accessToken disponible, no notificando');
        return;
      }

      print('   📡 Intentando notificar al backend...');
      print('   URL: $backendUrl/meetings/$meetingId/user-left');
      
      // Notificar de forma asíncrona sin bloquear
      final response = await http.post(
        Uri.parse('$backendUrl/meetings/$meetingId/user-left'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${accessToken.substring(0, 20)}***',
        },
        body: jsonEncode({'remoteUid': uid}),
      ).timeout(const Duration(seconds: 1), onTimeout: () {
        print('   ⏱️ TIMEOUT notificando usuario left');
        return http.Response('timeout', 0);
      });
      
      print('   Response status: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('   ✅ Backend notificado correctamente');
      } else if (response.statusCode == 0) {
        print('   ⚠️ Timeout (backend podría estar caído o sin internet)');
      } else {
        print('   ⚠️ Backend retornó: ${response.statusCode}');
      }
    } catch (e) {
      print('   ❌ Error notificando: $e');
    }
  }

  // 👋 Notificar al backend cuando se deja la llamada correctamente
  Future<void> notifyLeaveChannel() async {
    if (meetingId == null) return;

    try {
      final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';
      
      // Si tenemos authToken pasado directamente, usarlo
      String? accessToken = authToken;
      if (accessToken == null) {
        try {
          final session = Supabase.instance.client.auth.currentSession;
          accessToken = session?.accessToken;
        } catch (e) {
          print('⚠️ Supabase no inicializado, saltando leave notification: $e');
          return;
        }
      }
      
      if (accessToken == null) return;

      // BACKEND_URL ya incluye /api, así que solo agregar el resto del path
      final response = await http.post(
        Uri.parse('$backendUrl/meetings/$meetingId/leave'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        print('✅ Salida registrada en servidor');
      }
    } catch (e) {
      print('⚠️ Error registrando salida: $e');
    }
  }

  Future<void> leaveAndDispose() async {
    // Evitar doble-dispose
    if (_isDisposed) {
      print('⚠️ Controlador ya fue dispuesto, ignorando solicitud duplicada');
      return;
    }
    
    print('🧹 Limpiando controlador de video...');
    
    // Marcar como dispuesto inmediatamente para prevenir llamadas concurrentes
    _isDisposed = true;
    
    // Notificar salida (una sola vez)
    await notifyLeaveChannel();
    
    _joinTimeoutTimer?.cancel();
    try {
      await _engine.leaveChannel();
      await _engine.stopPreview();
      await _engine.release();
    } catch (e) {
      print('Error al cerrar Agora: $e');
    }
    
    // Disponer los ValueNotifiers
    try {
      localUserJoined.dispose();
      isAudioMuted.dispose();
      isVideoMuted.dispose();
      remoteUids.dispose();
      remoteScreenShareUids.dispose();
      otherUserLeft.dispose();
    } catch (e) {
      print('⚠️ Error al disponer ValueNotifiers: $e');
    }
  }

  void dispose() {
    // El dispose() sincrónico solo marca que debe limpiarse
    // La limpieza real ocurre en leaveAndDispose() que es asincrónico
    if (!_isDisposed) {
      _isDisposed = true;
    }
  }

  // Estos métodos ahora serán llamados por el event handler
  void addRemoteScreenShareUid(int uid) {
    final updated = Set<int>.from(remoteScreenShareUids.value)..add(uid);
    remoteScreenShareUids.value = updated;
    print(
      '[LOGIC] Added screen share UID: $uid. Current list: ${remoteScreenShareUids.value}',
    );
  }

  void removeRemoteScreenShareUid(int uid) {
    final updated = Set<int>.from(remoteScreenShareUids.value)..remove(uid);
    remoteScreenShareUids.value = updated;
    print(
      '[LOGIC] Removed screen share UID: $uid. Current list: ${remoteScreenShareUids.value}',
    );
  }
}
