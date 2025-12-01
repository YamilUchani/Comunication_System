import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_rtc_engine/src/agora_base.dart';

class CaptureSource {
  final int id;
  final String name;
  final Rectangle region; // Área completa a capturar
  final Uint8List? thumbData; // Miniatura opcional
  final bool isDisplay;

  CaptureSource({
    required this.id,
    required this.name,
    required this.region,
    this.thumbData,
    required this.isDisplay,
  });
}

class ScreenShareController extends ChangeNotifier {
  final RtcEngine _engine;
  bool _isInitialized = false;

  ScreenShareController({required RtcEngine engine}) : _engine = engine;

  final ValueNotifier<bool> isSharingNotifier = ValueNotifier(false);
  bool get isSharing => isSharingNotifier.value;

  final List<CaptureSource> _availableDisplays = [];
  final List<CaptureSource> _availableWindows = [];

  List<CaptureSource> get availableDisplays => _availableDisplays;
  List<CaptureSource> get availableWindows => _availableWindows;

  Future<void> initialize() async {
    try {
      final hasPermission = await _checkPermissions();
      if (!hasPermission) throw 'Screen sharing permissions not granted';

      final sources = await _engine.getScreenCaptureSources(
        thumbSize: const SIZE(width: 150, height: 100),
        iconSize: const SIZE(width: 0, height: 0),
        includeScreen: true,
      );

      _availableDisplays.clear();
      _availableWindows.clear();

      for (final source in sources) {
        if (source.sourceId == null) continue;

        final region = Rectangle(
          x: source.position?.x ?? 0,
          y: source.position?.y ?? 0,
          width: source.position?.width ?? 0,
          height: source.position?.height ?? 0,
        );

        if (source.type ==
            ScreenCaptureSourceType.screencapturesourcetypeScreen) {
          _availableDisplays.add(
            CaptureSource(
              id: source.sourceId!,
              name: source.sourceName ?? 'Pantalla ${source.sourceId}',
              region: region,
              thumbData: source.thumbImage?.buffer,
              isDisplay: true,
            ),
          );
        } else if (source.type ==
            ScreenCaptureSourceType.screencapturesourcetypeWindow) {
          _availableWindows.add(
            CaptureSource(
              id: source.sourceId!,
              name: source.sourceName ?? 'Ventana ${source.sourceId}',
              region: region,
              thumbData: source.thumbImage?.buffer,
              isDisplay: false,
            ),
          );
        }
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing screen sharing: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<bool> _checkPermissions() async => true;

  Widget buildThumbnail(CaptureSource source) {
    try {
      if (source.thumbData != null) {
        return Image.memory(
          source.thumbData!,
          width: 150,
          height: 100,
          fit: BoxFit.contain,
        );
      } else {
        return Container(
          width: 150,
          height: 100,
          color: Colors.grey.withOpacity(0.3),
          child: Center(
            child: Icon(
              source.isDisplay ? Icons.desktop_windows : Icons.window,
              size: 48,
              color: Colors.white70,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error building thumbnail: $e');
      return Container(
        width: 150,
        height: 100,
        color: Colors.grey.withOpacity(0.3),
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.red, size: 48),
        ),
      );
    }
  }

  Future<void> startSharing(CaptureSource source) async {
    try {
      if (!_isInitialized) await initialize();

      final captureParams = const ScreenCaptureParameters(
        frameRate: 15,
        bitrate: 1200,
        // Evita capturar el cursor del ratón si no lo deseas
        captureMouseCursor: true,
      );
      if (source.isDisplay) {
        await _engine.startScreenCaptureByDisplayId(
          displayId: source.id,
          regionRect: source.region,
          captureParams: captureParams,
        );
        print(
          '[LOCAL] startScreenCaptureByDisplayId llamado. ¡El usuario local está compartiendo pantalla!',
        );
      } else {
        await _engine.startScreenCaptureByWindowId(
          windowId: source.id,
          regionRect: source.region,
          captureParams: captureParams,
        );
        print(
          '[LOCAL] startScreenCaptureByWindowId llamado. ¡El usuario local está compartiendo pantalla!',
        );
      }
      await _engine.updateChannelMediaOptions(
        const ChannelMediaOptions(
          publishCameraTrack: false, // Apagamos la cámara
          publishScreenTrack: true, // Encendemos la pantalla
        ),
      );
      isSharingNotifier.value = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error starting screen sharing: $e');
      isSharingNotifier.value = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stopSharing() async {
    try {
      await _engine.stopScreenCapture();

      // CORRECCIÓN: Revertimos los cambios.
      // Dejamos de publicar la pantalla y volvemos a encender la cámara.
      await _engine.updateChannelMediaOptions(
        const ChannelMediaOptions(
          publishScreenTrack: false, // Apagamos la pantalla
          publishCameraTrack: true, // Volvemos a la cámara
        ),
      );

      print('[LOCAL] Dejó de compartir pantalla y volvió a la cámara.');
      isSharingNotifier.value = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping screen sharing: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    if (isSharing) stopSharing();
    isSharingNotifier.dispose();
    super.dispose();
  }
}
