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
  Timer? _heartbeatTimer; // ❤️ Timer para enviar heartbeats

  VideoCallController({
    required this.channelName,
    required this.token,
    int? uid,
    this.meetingId,
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

      // CORRECCIÓN: El manejador de eventos ahora es mucho más robusto.
      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            // ✅ Cancelar el timeout si se recibe el evento
            _joinTimeoutTimer?.cancel();
            
            // Si nos unimos con UID 0, Agora nos asigna uno real aquí
            if (connection.localUid != null && connection.localUid != 0) {
              _localUid = connection.localUid!;
            }
            localUserJoined.value = true;
            print(
              '[EVENT] onJoinChannelSuccess: connection=$connection, elapsed=$elapsed',
            );
          },
          onUserJoined: (connection, uid, elapsed) {
            final currentUids = Set<int>.from(remoteUids.value);
            currentUids.add(uid);
            remoteUids.value = currentUids;
            print('[EVENT] onUserJoined: uid=$uid, connection=$connection');
          },
          onUserOffline: (connection, uid, reason) {
            final currentUids = Set<int>.from(remoteUids.value);
            final currentScreenShareUids = Set<int>.from(
              remoteScreenShareUids.value,
            );
            currentUids.remove(uid);
            // Si el usuario se va, también deja de compartir pantalla.
            currentScreenShareUids.remove(uid);
            remoteUids.value = currentUids;
            remoteScreenShareUids.value = currentScreenShareUids;
            print('[EVENT] onUserOffline: uid=$uid, reason=$reason');
          },
          onRemoteVideoStateChanged:
              (connection, remoteUid, state, reason, elapsed) {
                print(
                  '[EVENT] onRemoteVideoStateChanged: uid=$remoteUid, state=$state, reason=$reason',
                );
              },
          // CORRECCIÓN: Usaremos onVideoSizeChanged para detectar el stream de pantalla.
          // Cuando un stream de pantalla llega, el sourceType será videoSourceScreen.
          onVideoSizeChanged: (connection, sourceType, uid, width, height, rotation) {
            print(
              '[EVENT] onVideoSizeChanged: uid=$uid, sourceType=$sourceType, width=$width, height=$height',
            );

            // Verificamos el tipo de fuente del video
            if (sourceType == VideoSourceType.videoSourceScreen) {
              // Si vemos un video de tipo "pantalla" de este usuario, lo añadimos a la lista.
              print(
                '[SCREEN SHARE] Usuario $uid está compartiendo pantalla (${width}x$height)',
              );
              addRemoteScreenShareUid(uid);
            } else if (sourceType == VideoSourceType.videoSourceCamera ||
                sourceType == VideoSourceType.videoSourceCameraPrimary) {
              // Si el video es de la cámara, nos aseguramos de que no esté en la lista de pantalla compartida.
              print(
                '[CAMERA] Usuario $uid está usando cámara (${width}x$height)',
              );
              removeRemoteScreenShareUid(uid);
            }
          },
        ),
      );

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

      // Sobrescribir el handler para completar el completer
      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            _joinTimeoutTimer?.cancel();
            if (connection.localUid != null && connection.localUid != 0) {
              _localUid = connection.localUid!;
            }
            localUserJoined.value = true;
            if (!completer.isCompleted) completer.complete();
            print('[EVENT] onJoinChannelSuccess: connection=$connection');
            
            // ❤️ Iniciar heartbeat cuando se une exitosamente
            _startHeartbeat();
          },
          onError: (err, msg) {
            print('❌ Agora Error: $err, $msg');
            if (!completer.isCompleted) completer.completeError('Error de Agora: $err - $msg');
          },
          onUserJoined: (connection, uid, elapsed) {
            final currentUids = Set<int>.from(remoteUids.value)..add(uid);
            remoteUids.value = currentUids;
          },
          onUserOffline: (connection, uid, reason) {
            print('[EVENT] onUserOffline: uid=$uid, reason=$reason');
            final currentUids = Set<int>.from(remoteUids.value)..remove(uid);
            remoteUids.value = currentUids;
            
            // También remover de pantalla compartida si estuviera
            if (remoteScreenShareUids.value.contains(uid)) {
              removeRemoteScreenShareUid(uid);
            }
          },
          onConnectionStateChanged: (connection, state, reason) {
            print('[EVENT] onConnectionStateChanged: state=$state, reason=$reason');
          },
          onNetworkQuality: (connection, uid, txQuality, rxQuality) {
            // Loguear solo si la calidad es muy mala (6 = DOWN)
            if (uid != 0 && rxQuality.index >= 5) {
              print('⚠️ Mala calidad de red detectada para usuario $uid: $rxQuality');
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

      // Esperar al éxito o al fallo/timeout
      return completer.future;
    } catch (e) {
      debugPrint('Error al inicializar Agora: $e');
      _joinTimeoutTimer?.cancel();
      rethrow;
    }
  }

  Future<void> toggleAudio() async {
    final newMuteState = !isAudioMuted.value;
    await _engine.muteLocalAudioStream(newMuteState);
    isAudioMuted.value = newMuteState;
  }

  Future<void> toggleVideo() async {
    final newMuteState = !isVideoMuted.value;
    await _engine.muteLocalVideoStream(newMuteState);
    isVideoMuted.value = newMuteState;
  }

  // ❤️ HEARTBEAT: Enviar latido a Supabase cada 3 segundos
  void _startHeartbeat() {
    if (meetingId == null) {
      print('⚠️ No meeting ID, heartbeat no iniciado');
      return;
    }

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _sendHeartbeat();
    });
    print('❤️ Heartbeat iniciado cada 3 segundos');
  }

  Future<void> _sendHeartbeat() async {
    try {
      final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final response = await http.post(
        Uri.parse('$backendUrl/api/meetings/$meetingId/heartbeat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () => http.Response('timeout', 500),
      );

      if (response.statusCode == 200) {
        print('✅ Heartbeat enviado');
      } else {
        print('⚠️ Error heartbeat: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error enviando heartbeat: $e');
    }
  }

  // 👋 Notificar al backend cuando se deja la llamada correctamente
  Future<void> notifyLeaveChannel() async {
    if (meetingId == null) return;

    try {
      final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:3000';
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final response = await http.post(
        Uri.parse('$backendUrl/api/meetings/$meetingId/leave'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
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
    print('🧹 Limpiando controlador de video...');
    
    // Detener heartbeat y notificar salida
    _heartbeatTimer?.cancel();
    await notifyLeaveChannel();
    
    _joinTimeoutTimer?.cancel();
    try {
      await _engine.leaveChannel();
      await _engine.stopPreview();
      await _engine.release();
    } catch (e) {
      print('Error al cerrar Agora: $e');
    }
    localUserJoined.dispose();
    isAudioMuted.dispose();
    isVideoMuted.dispose();
    remoteUids.dispose();
    remoteScreenShareUids.dispose();
    otherUserLeft.dispose();
  }

  void dispose() {
    leaveAndDispose();
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
