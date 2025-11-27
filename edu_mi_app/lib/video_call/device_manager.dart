import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class DeviceManager {
  List<VideoDeviceInfo> cameras = [];
  List<AudioDeviceInfo> microphones = [];
  List<AudioDeviceInfo> speakers = [];

  String? selectedCamera;
  String? selectedMicrophone;
  String? selectedSpeaker;

  Future<void> refreshDevices(AudioDeviceManager audioManager, VideoDeviceManager videoManager) async {
    try {
      cameras = await videoManager.enumerateVideoDevices();
      microphones = await audioManager.enumerateRecordingDevices();
      speakers = await audioManager.enumeratePlaybackDevices();

      if (selectedCamera == null || !cameras.any((c) => c.deviceId == selectedCamera)) {
        selectedCamera = cameras.isNotEmpty ? cameras.first.deviceId : null;
      }

      if (selectedMicrophone == null || !microphones.any((m) => m.deviceId == selectedMicrophone)) {
        selectedMicrophone = microphones.isNotEmpty ? microphones.first.deviceId : null;
      }

      if (selectedSpeaker == null || !speakers.any((s) => s.deviceId == selectedSpeaker)) {
        selectedSpeaker = speakers.isNotEmpty ? speakers.first.deviceId : null;
      }
    } catch (e) {
      print('Error al refrescar dispositivos: $e');
    }
  }

  Future<void> changeCamera(VideoDeviceManager manager, String deviceId) async {
    try {
      await manager.setDevice(deviceId);
      selectedCamera = deviceId;
    } catch (e) {
      print('Error al cambiar cámara: $e');
    }
  }

  Future<void> changeMicrophone(AudioDeviceManager manager, String deviceId) async {
    try {
      await manager.setRecordingDevice(deviceId);
      selectedMicrophone = deviceId;
    } catch (e) {
      print('Error al cambiar micrófono: $e');
    }
  }

  Future<void> changeSpeaker(AudioDeviceManager manager, String deviceId) async {
    try {
      await manager.setPlaybackDevice(deviceId);
      selectedSpeaker = deviceId;
    } catch (e) {
      print('Error al cambiar altavoz: $e');
    }
  }

  List<String> get cameraNames => cameras.map((c) => c.deviceName ?? 'Cámara').toList();
  List<String> get cameraIds => cameras.map((c) => c.deviceId ?? '').toList();

  List<String> get microphoneNames => microphones.map((m) => m.deviceName ?? 'Micrófono').toList();
  List<String> get microphoneIds => microphones.map((m) => m.deviceId ?? '').toList();

  List<String> get speakerNames => speakers.map((s) => s.deviceName ?? 'Altavoz').toList();
  List<String> get speakerIds => speakers.map((s) => s.deviceId ?? '').toList();
}
