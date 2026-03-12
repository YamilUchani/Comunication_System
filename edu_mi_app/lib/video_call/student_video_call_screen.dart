// Archivo: student_video_call_screen.dart
// Sistema de videollamada simplificado solo para estudiantes
// - Solo 2 ventanas (estudiante + maestro)
// - Auto-compartir pantalla al entrar
// - Interfaz minimalista sin chat ni control de dispositivos

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'video_call_controller.dart';
import 'video_widgets.dart';
import 'screen_sharing_windows.dart';

class StudentVideoCallScreen extends StatefulWidget {
  final String channelName;
  final String token;
  final String userName;
  final String? meetingId;
  final String? authToken;

  const StudentVideoCallScreen({
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
  _StudentVideoCallScreenState createState() => _StudentVideoCallScreenState();
}

class _StudentVideoCallScreenState extends State<StudentVideoCallScreen>
    with WidgetsBindingObserver {
  late final VideoCallController controller;
  ScreenShareController? screenController;
  final Map<String, String> users = {};
  int? localUid;
  bool _isAutoShareActive = false; // 📺 Rastrear si auto-share está activo
  bool _showExitConfirm = false; // ❌ Mostrar diálogo de confirmación

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = VideoCallController(
      channelName: widget.channelName,
      token: widget.token,
      uid: widget.uid,
      meetingId: widget.meetingId,
      authToken: widget.authToken,
    );
    _initAgora();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    print('🚪 Estudiante saliendo de la videollamada...');
    await controller.leaveAndDispose();
    return AppExitResponse.exit;
  }

  Future<void> _initAgora() async {
    try {
      await controller.init();
      localUid = await _getLocalUid();

      if (mounted) {
        setState(() {
          screenController = ScreenShareController(engine: controller.engine);
          users[localUid.toString()] = widget.userName;
        });
        _updateUsersList();

        // 📺 Auto-compartir pantalla después de que se inicialize todo
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          _autoStartScreenShare();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al inicializar: $e')),
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
              users[uid.toString()] = 'Maestro';
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

  /// 📺 Auto-compartir pantalla al entrar
  Future<void> _autoStartScreenShare() async {
    try {
      if (screenController == null) return;

      print('[AUTO-SHARE] Inicializando auto-compartir pantalla...');
      await screenController!.initialize();

      // Intentar compartir la pantalla principal (display id 0 es típicamente la principal)
      if (screenController!.availableDisplays.isNotEmpty) {
        final primaryDisplay = screenController!.availableDisplays.first;
        print(
          '[AUTO-SHARE] Compartiendo pantalla principal: ${primaryDisplay.name}',
        );
        await screenController!.startSharing(primaryDisplay);

        if (mounted) {
          setState(() {
            _isAutoShareActive = true;
          });
        }

        // Mostrar notificación
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📺 Pantalla compartida automáticamente'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('[AUTO-SHARE] Error al auto-compartir: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo compartir pantalla: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// ⏹️ Detener compartición de pantalla
  Future<void> _stopScreenShare() async {
    try {
      if (screenController != null) {
        print('[STOP-SHARE] Deteniendo compartición de pantalla...');
        await screenController!.stopSharing();
        if (mounted) {
          setState(() {
            _isAutoShareActive = false;
          });
        }
      }
    } catch (e) {
      print('[STOP-SHARE] Error al detener: $e');
    }
  }

  /// ❌ Salir de la videollamada
  Future<void> _exitMeeting() async {
    // Detener compartición de pantalla primero
    if (_isAutoShareActive) {
      await _stopScreenShare();
    }
    // Salir del canal
    await controller.leaveAndDispose();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Mostrar confirmación al intentar cerrar
        setState(() {
          _showExitConfirm = true;
        });
        return false; // Bloquear navegación por defecto
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
                      'Conectando: ${widget.channelName}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Preparando pantalla compartida...',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              );
            }

            return Stack(
              children: [
                // 📹 Solo 2 ventanas: estudiante + maestro
                VideoWidgets(
                  controller: controller,
                  screenController: screenController,
                ),

                // 🎯 Controles minimalistas (solo salir)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton.extended(
                      onPressed: _exitMeeting,
                      backgroundColor: Colors.red,
                      label: const Text('Salir'),
                      icon: const Icon(Icons.call_end),
                    ),
                  ),
                ),

                // 📺 Indicador de estado de compartición
                if (screenController != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isAutoShareActive
                            ? Colors.green.withOpacity(0.8)
                            : Colors.orange.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isAutoShareActive ? Icons.check : Icons.hourglass_empty,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isAutoShareActive
                                ? 'Pantalla compartida'
                                : 'Compartiendo...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ❌ Diálogo de confirmación de salida
                if (_showExitConfirm)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Dialog(
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _showExitConfirm = false;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[700],
                                    ),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    onPressed: _exitMeeting,
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
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    screenController?.dispose();
    super.dispose();
  }
}
