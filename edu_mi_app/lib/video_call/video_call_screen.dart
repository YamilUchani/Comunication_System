// Archivo: video_call_screen.dart

import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'video_call_controller.dart';
import 'video_widgets.dart';
import 'controls_bar.dart';
import 'screen_sharing_windows.dart';
import '../main.dart' as main_module;
import 'chat/chat_controller.dart';
import 'chat/chat_screen.dart';
import 'device_manager.dart'; // Importa el DeviceManager
import '../services/meeting_cleanup_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String channelName;
  final String token;
  final String userName;
  final String? meetingId; // 🆔 ID de la reunión para heartbeat
  final String? authToken; // 🔑 Token de autenticación para heartbeat

  const VideoCallScreen({
    super.key,
    required this.channelName,
    required this.token,
    required this.userName,
    this.uid,
    this.meetingId,
    this.authToken,
  });

  final int? uid;

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> with WidgetsBindingObserver {
  late final VideoCallController controller;
  ScreenShareController? screenController;
  late ChatController chatController;
  DeviceManager? deviceManager; // Ahora es nullable
  final Map<String, String> users = {};
  int? localUid;
  bool _showChat = false; // 💬 Control de visibilidad del chat

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = VideoCallController(
      channelName: widget.channelName,
      token: widget.token,
      uid: widget.uid,
      meetingId: widget.meetingId,
      authToken: widget.authToken, // 🔑 Pasar token de autenticación
    );
    // 📝 Registrar este controlador para limpieza en logout
    MeetingCleanupService.registerActiveController(controller);
    _initAgora();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    print('🚪 Saliendo de la videollamada desde el sistema...');
    try {
      // Notificar a Agora que nos vamos para que no deje el video congelado a los demás
      await MeetingCleanupService.cleanupActiveMeeting(closeWindow: true);
    } catch (e) {
      print('⚠️ Error al salir: $e');
    }
    return AppExitResponse.exit;
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
          deviceManager?.refreshDevices(
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
          final currentUids = controller.remoteUids.value
              .map((uid) => uid.toString())
              .toList();
          users.removeWhere(
            (key, value) =>
                key != localUid.toString() && !currentUids.contains(key),
          );
        });
      }
    });
  }

  /// 💬 Toggle para mostrar/ocultar chat
  void _toggleChat() {
    setState(() {
      _showChat = !_showChat;
    });
    if (_showChat) {
      chatController.markMessagesAsRead();
    }
  }

  /// ❌ Salir de la videollamada
  Future<void> _exitMeeting() async {
    print('🚪 Saliendo de la videollamada...');
    
    try {
      // Ejecutar leaveAndDispose y esperar a que se complete
      await controller.leaveAndDispose();
      // Esperar un poco más para asegurar que Agora haya procesado la salida
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('⚠️ Error al salir de la videollamada: $e');
    }
    
    if (mounted) {
      // Si es una ventana secundaria, cerrar la aplicación completamente
      if (main_module.isSecondaryWindow) {
        print('🪟 Cerrando ventana secundaria de videollamada...');
        await Future.delayed(const Duration(milliseconds: 200));
        exit(0);
      } else {
        // Si es la pantalla principal, solo pop
        Navigator.pop(context);
      }
    }
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.grey[900],
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '¿Salir de la videollamada?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                      ),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _exitMeeting();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Salir'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        chatController.setContext(context);
      }
    });

    return WillPopScope(
      onWillPop: () async {
        _showExitDialog();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ValueListenableBuilder<bool>(
          valueListenable: controller.localUserJoined,
          builder: (context, joined, _) {
            if (!joined) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.teal),
                    const SizedBox(height: 20),
                    Text(
                      'Conectando a: ${widget.channelName}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Iniciando motor de Agora...',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              );
            }
            return Stack(
              children: [
                // 🎥 Video principal
                VideoWidgets(
                  controller: controller,
                  screenController: screenController,
                ),
                
                // 💬 Panel de chat desplegable a la derecha
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  right: _showChat ? 0 : -350,
                  top: 0,
                  bottom: 0,
                  width: 350,
                  child: Material(
                    color: Colors.grey[100],
                    child: Stack(
                      children: [
                        // Chat content
                        ChatScreen(
                          chatController: chatController,
                          users: users,
                        ),
                        
                        // Botón para cerrar (esquina superior derecha)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.black, size: 20),
                              onPressed: _toggleChat,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
              onExit: _exitMeeting, // Pasar el callback para salir
              onToggleChat: _toggleChat, // Pasar el callback para toggle del chat
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // leaveAndDispose ya fue llamado en _exitMeeting() o didRequestAppExit()
    // controller.dispose() ahora es sincrónico y seguro llamar múltiples veces
    controller.dispose();
    screenController?.dispose();
    chatController.dispose();
    super.dispose();
  }
}
