// Archivo: student_video_call_screen.dart
// Sistema de videollamada simplificado solo para estudiantes
// - Layout vertical (pantalla arriba, cámara abajo)
// - Mostrar pantalla O cámara, no ambos
// - Controles en la parte inferior: chat, compartir, cámara, micrófono, etc

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'video_call_controller.dart';
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
  int? localUid;
  
  // Estados de controles
  bool _isAutoShareActive = false;
  bool _isCameraOn = true;
  bool _isMicOn = true;
  bool _showChat = false;
  bool _showExitConfirm = false;
  
  // Pantalla vs Cámara
  bool _showScreenShare = false; // true = pantalla, false = cámara

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
        });

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

  /// 📺 Auto-compartir pantalla al entrar
  Future<void> _autoStartScreenShare() async {
    try {
      if (screenController == null) return;

      print('[AUTO-SHARE] Inicializando auto-compartir pantalla...');
      await screenController!.initialize();

      if (screenController!.availableDisplays.isNotEmpty) {
        final primaryDisplay = screenController!.availableDisplays.first;
        print('[AUTO-SHARE] Compartiendo: ${primaryDisplay.name}');
        await screenController!.startSharing(primaryDisplay);

        if (mounted) {
          setState(() {
            _isAutoShareActive = true;
            _showScreenShare = true; // Mostrar pantalla por defecto
          });
        }

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
      print('[AUTO-SHARE] Error: $e');
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
        print('[STOP-SHARE] Deteniendo...');
        await screenController!.stopSharing();
        if (mounted) {
          setState(() {
            _isAutoShareActive = false;
            _showScreenShare = false; // Volver a cámara
          });
        }
      }
    } catch (e) {
      print('[STOP-SHARE] Error: $e');
    }
  }

  /// 🎥 Toggle cámara
  void _toggleCamera() async {
    setState(() {
      _isCameraOn = !_isCameraOn;
    });
    await controller.toggleVideo();
  }

  /// 🎤 Toggle micrófono
  void _toggleMic() async {
    setState(() {
      _isMicOn = !_isMicOn;
    });
    await controller.toggleAudio();
  }

  /// ❌ Salir de la videollamada
  Future<void> _exitMeeting() async {
    if (_isAutoShareActive) {
      await _stopScreenShare();
    }
    await controller.leaveAndDispose();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        setState(() {
          _showExitConfirm = true;
        });
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
                      'Conectando: ${widget.channelName}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Preparando pantalla compartida...',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              );
            }

            return Stack(
              children: [
                // 📹 PANTALLA COMPLETA: Contenido principal (pantalla o cámara)
                Container(
                  color: Colors.black,
                  child: _showScreenShare && _isAutoShareActive
                      ? _buildScreenShareView()
                      : _buildCameraView(),
                ),

                // 🎛️ CONTROLES VERTICALES EN LA DERECHA
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: _buildVerticalControlsBar(),
                ),

                // ========== INDICADOR DE COMPARTICIÓN ==========
                if (screenController != null)
                  Positioned(
                    top: 10,
                    left: 10,
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
                            _isAutoShareActive
                                ? Icons.check_circle
                                : Icons.hourglass_empty,
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

                // ========== DIÁLOGO DE CONFIRMACIÓN ==========
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

  /// 🎥 Construir vista de pantalla compartida
  Widget _buildScreenShareView() {
    if (screenController == null) {
      return const Center(
        child: Text(
          'Pantalla no disponible',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          '📺 Pantalla Compartida',
          style: TextStyle(color: Colors.white54, fontSize: 18),
        ),
      ),
    );
  }

  /// 🎥 Construir vista pequeña de pantalla
  Widget _buildScreenShareSmall() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Text(
          '📺 Pantalla (compartiendo)',
          style: TextStyle(color: Colors.white38, fontSize: 14),
        ),
      ),
    );
  }

  /// 📹 Construir vista de cámara del estudiante
  Widget _buildCameraView() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: _isCameraOn
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam,
                    size: 80,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tu Cámara',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 18,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.videocam_off,
                    size: 80,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Cámara Apagada',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// 📹 Construir vista pequeña de cámara
  Widget _buildCameraViewSmall() {
    return Container(
      color: Colors.black87,
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.teal, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            Icons.person,
            size: 40,
            color: Colors.white24,
          ),
        ),
      ),
    );
  }

  /// 🎛️ Barra de controles VERTICAL (sidebar derecha)
  Widget _buildVerticalControlsBar() {
    return Container(
      width: 80,
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 📹 Toggle Cámara
          _buildVerticalControlButton(
            icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
            label: 'Cámara',
            color: _isCameraOn ? Colors.white : Colors.red,
            onPressed: _toggleCamera,
          ),
          const SizedBox(height: 16),

          // 🎤 Toggle Micrófono
          _buildVerticalControlButton(
            icon: _isMicOn ? Icons.mic : Icons.mic_off,
            label: 'Micrófono',
            color: _isMicOn ? Colors.white : Colors.red,
            onPressed: _toggleMic,
          ),
          const SizedBox(height: 16),

          // 📺 Compartir Pantalla
          _buildVerticalControlButton(
            icon: _isAutoShareActive
                ? Icons.stop_screen_share
                : Icons.screen_share,
            label: 'Pantalla',
            color: _isAutoShareActive ? Colors.orange : Colors.white,
            onPressed: () {
              if (_isAutoShareActive) {
                _stopScreenShare();
              } else {
                _autoStartScreenShare();
              }
            },
          ),
          const SizedBox(height: 16),

          // 💬 Chat
          _buildVerticalControlButton(
            icon: Icons.chat,
            label: 'Chat',
            color: Colors.white,
            onPressed: () {
              setState(() {
                _showChat = !_showChat;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('💬 Chat (próximamente)'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // ❌ Salir
          _buildVerticalControlButton(
            icon: Icons.call_end,
            label: 'Salir',
            color: Colors.red,
            onPressed: () {
              setState(() {
                _showExitConfirm = true;
              });
            },
          ),
        ],
      ),
    );
  }

  /// Botón de control VERTICAL individual
  Widget _buildVerticalControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.2),
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
