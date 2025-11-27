// Archivo: video_call_controller.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VideoCallController {
  final String channelName;
  final String token;
  final ValueNotifier<bool> localUserJoined = ValueNotifier(false);
  final ValueNotifier<bool> isAudioMuted = ValueNotifier(false);
  final ValueNotifier<bool> isVideoMuted = ValueNotifier(false);
  final ValueNotifier<Set<int>> remoteUids = ValueNotifier({});
  // CORRECCIÓN: Este ValueNotifier es clave para que la UI sepa quién comparte pantalla.
  final ValueNotifier<Set<int>> remoteScreenShareUids = ValueNotifier({});

  late RtcEngine _engine;
  RtcEngine get engine => _engine;
  int _localUid = 0;

  int get localUid => _localUid;

  VideoCallController({
    required this.channelName,
    required this.token,
  });

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
            localUserJoined.value = true;
            print('[EVENT] onJoinChannelSuccess: connection=$connection, elapsed=$elapsed');
          },
          onUserJoined: (connection, uid, elapsed) {
            final currentUids = Set<int>.from(remoteUids.value);
            currentUids.add(uid);
            remoteUids.value = currentUids;
            print('[EVENT] onUserJoined: uid=$uid, connection=$connection');
          },
          onUserOffline: (connection, uid, reason) {
            final currentUids = Set<int>.from(remoteUids.value);
            final currentScreenShareUids = Set<int>.from(remoteScreenShareUids.value);
            currentUids.remove(uid);
            // Si el usuario se va, también deja de compartir pantalla.
            currentScreenShareUids.remove(uid);
            remoteUids.value = currentUids;
            remoteScreenShareUids.value = currentScreenShareUids;
            print('[EVENT] onUserOffline: uid=$uid, reason=$reason');
          },
          // CORRECCIÓN: Este es el evento MÁS IMPORTANTE para la pantalla compartida.
          onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
            print('[EVENT] onRemoteVideoStateChanged: uid=$remoteUid, state=$state, reason=$reason');

            // Verificamos si la fuente del video es la PANTALLA
            // Nota: En algunas versiones del SDK, la fuente viene en otro evento o se infiere.
            // La lógica moderna se centra en si el estado es 'Playing' para una fuente de pantalla.
            // Esta es la forma más efectiva de saberlo:
            
            final isScreenShareSource = state == RemoteVideoState.remoteVideoStateStarting || state == RemoteVideoState.remoteVideoStateDecoding;

            // Para ser más precisos, necesitamos saber la fuente. El SDK debería proveerla.
            // Si tu versión no la provee en este evento, la lógica de 'joinChannelEx' con un UID diferente es la alternativa.
            // Sin embargo, la forma más moderna es la siguiente:
            
            // Un usuario EMPIEZA a compartir su pantalla
            if (reason == RemoteVideoStateReason.remoteVideoStateReasonRemoteUnmuted) {
                 // Esta lógica asume que si un usuario ya visible (cámara) manda un segundo stream, es pantalla.
                 // La forma 100% segura es usando onRemoteVideoStats para ver la fuente o `joinChannelEx` con un UID dedicado.
                 // Por ahora, vamos a usar `onVideoSizeChanged` como un truco para detectarlo.
            }

            // Un usuario DEJA de compartir su pantalla
            if (reason == RemoteVideoStateReason.remoteVideoStateReasonRemoteMuted) {
                // Aquí también es difícil saber si mutó la cámara o la pantalla.
            }
          },
          // CORRECCIÓN #2: Usaremos onVideoSizeChanged como una forma de detectar el stream de pantalla.
          // Cuando un stream de pantalla llega, suele tener una resolución diferente y el `sourceType` sí se especifica aquí.
          onVideoSizeChanged: (connection, sourceType, uid, width, height, rotation) {
              print('[EVENT] onVideoSizeChanged: uid=$uid, sourceType=$sourceType, width=$width, height=$height');
              if (sourceType == VideoSourceType.videoSourceScreen) {
                  // Si vemos un video de tipo "pantalla" de este usuario, lo añadimos a la lista.
                  addRemoteScreenShareUid(uid);
              } else if (sourceType == VideoSourceType.videoSourceCamera) {
                  // Si el video es de la cámara, nos aseguramos de que no esté en la lista de pantalla compartida.
                  removeRemoteScreenShareUid(uid);
              }
          },
        ),
      );

      final uid = Random().nextInt(1000000);
      _localUid = uid;

      await _engine.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          // El usuario se une con su cámara por defecto
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          // Y con la pantalla apagada por defecto
          publishScreenTrack: false,
        ),
      );
    } catch (e) {
      debugPrint('Error al inicializar Agora: $e');
      rethrow;
    }
  }

  // ... (toggleAudio y toggleVideo se mantienen igual) ...

  void dispose() {
    _engine.leaveChannel();
    _engine.stopPreview();
    _engine.release();
    localUserJoined.dispose();
    isAudioMuted.dispose();
    isVideoMuted.dispose();
    remoteUids.dispose();
    remoteScreenShareUids.dispose(); // No olvides hacer dispose
  }

  // Estos métodos ahora serán llamados por el event handler
  void addRemoteScreenShareUid(int uid) {
    final updated = Set<int>.from(remoteScreenShareUids.value)..add(uid);
    remoteScreenShareUids.value = updated;
    print('[LOGIC] Added screen share UID: $uid. Current list: ${remoteScreenShareUids.value}');
  }

  void removeRemoteScreenShareUid(int uid) {
    final updated = Set<int>.from(remoteScreenShareUids.value)..remove(uid);
    remoteScreenShareUids.value = updated;
    print('[LOGIC] Removed screen share UID: $uid. Current list: ${remoteScreenShareUids.value}');
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
}