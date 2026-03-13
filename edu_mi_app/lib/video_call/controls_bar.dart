import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'video_call_controller.dart';
import 'screen_selection_screen.dart';
import 'screen_sharing_windows.dart';
import 'chat/chat_controller.dart';
import 'device_manager.dart';

class ControlsBar extends StatelessWidget {
  final VideoCallController controller;
  final ScreenShareController screenController;
  final ChatController chatController;
  final Map<String, String> users;
  final DeviceManager? deviceManager; // Ahora es nullable
  final VoidCallback? onExit; // Callback opcional para salir correctamente
  final VoidCallback? onToggleChat; // Callback para toggle del chat

  const ControlsBar({
    super.key,
    required this.controller,
    required this.screenController,
    required this.chatController,
    required this.users,
    required this.deviceManager,
    this.onExit,
    this.onToggleChat,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        color: Colors.black.withOpacity(0.5),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Botón de micrófono
              ValueListenableBuilder<bool>(
                valueListenable: controller.isAudioMuted,
                builder: (context, isMuted, child) {
                  return IconButton(
                    icon: Icon(
                      isMuted ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: controller.toggleAudio,
                  );
                },
              ),

              // Botón de cámara
              ValueListenableBuilder<bool>(
                valueListenable: controller.isVideoMuted,
                builder: (context, isMuted, child) {
                  return IconButton(
                    icon: Icon(
                      isMuted ? Icons.videocam_off : Icons.videocam,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: controller.toggleVideo,
                  );
                },
              ),

              // Botón de compartir pantalla
              ValueListenableBuilder<bool>(
                valueListenable: screenController.isSharingNotifier,
                builder: (context, isSharing, child) {
                  return IconButton(
                    icon: Icon(
                      isSharing ? Icons.stop_screen_share : Icons.screen_share,
                      color: isSharing ? Colors.red : Colors.white,
                      size: 30,
                    ),
                    onPressed: () async {
                      if (isSharing) {
                        await screenController.stopSharing();
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ScreenSelectionScreen(
                              controller: screenController,
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              ),

              // Botón para menú de dispositivos
              PopupMenuButton<String>(
                icon: const Icon(Icons.settings, color: Colors.white, size: 30),
                itemBuilder: (context) {
                  // Si deviceManager no está disponible, mostrar mensaje
                  if (deviceManager == null) {
                    return [
                      const PopupMenuItem<String>(
                        enabled: false,
                        child: Text('Dispositivos no disponibles'),
                      ),
                    ];
                  }

                  return [
                    // Submenú para cámaras
                    const PopupMenuItem<String>(
                      enabled: false,
                      child: Text(
                        'Cámaras',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...deviceManager!.cameras.map((camera) {
                      return PopupMenuItem<String>(
                        value: 'camera_${camera.deviceId}',
                        child: ListTile(
                          leading: const Icon(Icons.camera_alt),
                          title: Text(camera.deviceName ?? 'Cámara sin nombre'),
                          onTap: () {
                            Navigator.pop(context);
                            if (camera.deviceId != null) {
                              deviceManager!.changeCamera(
                                controller.engine.getVideoDeviceManager(),
                                camera.deviceId!,
                              );
                            }
                          },
                        ),
                      );
                    }),

                    const PopupMenuDivider(),

                    // Submenú para micrófonos
                    const PopupMenuItem<String>(
                      enabled: false,
                      child: Text(
                        'Micrófonos',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...deviceManager!.microphones.map((microphone) {
                      return PopupMenuItem<String>(
                        value: 'microphone_${microphone.deviceId}',
                        child: ListTile(
                          leading: const Icon(Icons.mic),
                          title: Text(
                            microphone.deviceName ?? 'Micrófono sin nombre',
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            if (microphone.deviceId != null) {
                              deviceManager!.changeMicrophone(
                                controller.engine.getAudioDeviceManager(),
                                microphone.deviceId!,
                              );
                            }
                          },
                        ),
                      );
                    }),

                    const PopupMenuDivider(),

                    // Submenú para altavoces
                    const PopupMenuItem<String>(
                      enabled: false,
                      child: Text(
                        'Altavoces',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...deviceManager!.speakers.map((speaker) {
                      return PopupMenuItem<String>(
                        value: 'speaker_${speaker.deviceId}',
                        child: ListTile(
                          leading: const Icon(Icons.speaker),
                          title: Text(
                            speaker.deviceName ?? 'Altavoz sin nombre',
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            if (speaker.deviceId != null) {
                              deviceManager!.changeSpeaker(
                                controller.engine.getAudioDeviceManager(),
                                speaker.deviceId!,
                              );
                            }
                          },
                        ),
                      );
                    }),
                  ];
                },
                onSelected: (value) {
                  // La selección se maneja directamente en los onTap de los ListTile
                },
              ),

              // Menú de reacciones
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.emoji_emotions,
                  color: Colors.white,
                  size: 30,
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'like',
                    child: ListTile(
                      leading: Icon(Icons.thumb_up, color: Colors.blue),
                      title: Text('Me gusta'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'hand',
                    child: ListTile(
                      leading: Icon(Icons.waving_hand, color: Colors.orange),
                      title: Text('Levantar mano'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clap',
                    child: ListTile(
                      leading: Icon(Icons.celebration, color: Colors.yellow),
                      title: Text('Aplaudir'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'heart',
                    child: ListTile(
                      leading: Icon(Icons.favorite, color: Colors.red),
                      title: Text('Corazón'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'fire',
                    child: ListTile(
                      leading: Icon(
                        Icons.local_fire_department,
                        color: Colors.orange,
                      ),
                      title: Text('Fuego'),
                    ),
                  ),
                ],
                onSelected: (reaction) {
                  chatController.sendReaction(reaction);
                },
              ),

              // Botón de chat
              ValueListenableBuilder<bool>(
                valueListenable: chatController.hasUnreadMessages,
                builder: (context, hasUnread, child) {
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.chat,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: onToggleChat ?? () {
                          // onToggleChat debe ser proporcionado por VideoCallScreen
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Chat no disponible')),
                          );
                        },
                      ),
                      if (hasUnread)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 12,
                              minHeight: 12,
                            ),
                            child: const Text(
                              '!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),

              // Botón de colgar
              IconButton(
                icon: const Icon(Icons.call_end, color: Colors.red, size: 30),
                onPressed: () {
                  if (onExit != null) {
                    // Si hay un callback para salir, usarlo
                    onExit!();
                  } else {
                    // Fallback: simplemente pop si no hay callback
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
