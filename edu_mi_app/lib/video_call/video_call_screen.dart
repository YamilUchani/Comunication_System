// Archivo: video_call_screen.dart

import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'video_call_controller.dart';
import 'video_widgets.dart';
import 'controls_bar.dart';
import 'screen_sharing_windows.dart';
import 'chat/chat_controller.dart';
import 'device_manager.dart'; // Importa el DeviceManager

class VideoCallScreen extends StatefulWidget {
  final String channelName;
  final String token;
  final String userName;

  const VideoCallScreen({
    super.key,
    required this.channelName,
    required this.token,
    required this.userName,
  });

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final VideoCallController controller;
  ScreenShareController? screenController;
  late ChatController chatController;
  late DeviceManager deviceManager; 
  final Map<String, String> users = {};
  int? localUid;

  @override
  void initState() {
    super.initState();
    controller = VideoCallController(
      channelName: widget.channelName,
      token: widget.token,
    );
    _initAgora();
  }

  Future<void> _initAgora() async {
    try {
      await controller.init();
      localUid = await _getLocalUid();

      if (mounted) {
        setState(() {
          screenController = ScreenShareController(engine: controller.engine);
          chatController = ChatController(
            engine: controller.engine,
            localUserId: localUid.toString(),
            localUserName: widget.userName,
          );
          users[localUid.toString()] = widget.userName;
          
          // Inicializa el DeviceManager después de que el motor de Agora esté listo
          deviceManager = DeviceManager();
          deviceManager.refreshDevices(
            controller.engine.getAudioDeviceManager(),
            controller.engine.getVideoDeviceManager(),
          );
        });
        _updateUsersList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al inicializar la llamada: $e')),
        );
      }
    }
  }

  Future<int> _getLocalUid() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return controller.localUid;
  }

  void _updateUsersList() {
    controller.remoteUids.addListener(() {
      if (mounted) {
        setState(() {
          for (final uid in controller.remoteUids.value) {
            if (!users.containsKey(uid.toString())) {
              users[uid.toString()] = 'Usuario $uid';
            }
          }
          final currentUids =
              controller.remoteUids.value.map((uid) => uid.toString()).toList();
          users.removeWhere((key, value) =>
              key != localUid.toString() && !currentUids.contains(key));
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && chatController != null) {
        chatController.setContext(context);
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<bool>(
        valueListenable: controller.localUserJoined,
        builder: (context, joined, _) {
          if (!joined) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stack(
            children: [
              VideoWidgets(
                controller: controller,
                screenController: screenController,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: controller.localUserJoined,
        builder: (context, joined, _) {
          if (!joined || screenController == null) {
            return const SizedBox.shrink();
          }
          return ControlsBar(
            controller: controller,
            screenController: screenController!,
            chatController: chatController,
            users: users,
            deviceManager: deviceManager,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    screenController?.dispose();
    chatController.dispose();
    super.dispose();
  }
}