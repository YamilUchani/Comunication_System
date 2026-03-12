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
  void initState() {    print('🔴 [StudentVideoCallScreenState] initState() INICIANDO');    print('🔴 [StudentVideoCallScreen] initState() INICIANDO');
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = VideoCallController(
      channelName: widget.channelName,
      token: widget.token,
      uid: widget.uid,
      meetingId: widget.meetingId,
      authToken: widget.authToken,
    );
    print('🔴 [StudentVideoCallScreen] Controller creado, llamando _initAgora()');
    _initAgora();
    print('🔴 [StudentVideoCallScreen] _initAgora() llamado, esperando resultado...');
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    print('🚪 Estudiante saliendo de la videollamada...');
    await controller.leaveAndDispose();
    return AppExitResponse.exit;
  }

  Future<void> _initAgora() async {
    try {
      print('[INIT] 🔄 Inicializando Agora...');
      await controller.init();
      print('[INIT] ✅ Agora inicializado');
      
      localUid = await _getLocalUid();
      print('[INIT] ✅ Local UID: $localUid');

      if (mounted) {
        setState(() {
          screenController = ScreenShareController(engine: controller.engine);
        });
        print('[INIT] ✅ ScreenShareController creado');
        print('[INIT] ✅ Listo para compartir pantalla manualmente');
      }
    } catch (e) {
      print('[INIT] ❌ Error: $e');
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

  /// 📺 Iniciar compartición de pantalla (se llama cuando usuario hace clic)
  Future<void> _startScreenShare() async {
    try {
      if (screenController == null) {
        print('[SCREEN-SHARE] ❌ screenController es null');
        _showError('Error: Controller no inicializado');
        return;
      }

      if (_isAutoShareActive) {
        print('[SCREEN-SHARE] Ya está compartiendo, deteniendo...');
        await _stopScreenShare();
        return;
      }

      print('[SCREEN-SHARE] 📺 Iniciando compartición de pantalla...');
      
      // Inicializar y obtener displays disponibles
      if (!screenController!.isInitialized) {
        print('[SCREEN-SHARE] 🔍 Buscando pantallas disponibles...');
        try {
          await screenController!.initialize();
          print('[SCREEN-SHARE] ✅ Inicialización completa');
        } catch (e) {
          print('[SCREEN-SHARE] ❌ Error en initialize(): $e');
          _showError('No se pueden obtener las pantallas: $e');
          return;
        }
      }

      // Verificar displays disponibles
      print('[SCREEN-SHARE] Displays disponibles: ${screenController!.availableDisplays.length}');
      if (screenController!.availableDisplays.isEmpty) {
        print('[SCREEN-SHARE] ❌ No hay displays disponibles');
        _showError('No se encontraron pantallas para compartir');
        return;
      }

      // Iniciar compartición
      final primaryDisplay = screenController!.availableDisplays.first;
      print('[SCREEN-SHARE] 📺 Compartiendo: ${primaryDisplay.name}');
      
      try {
        await screenController!.startSharing(primaryDisplay);
        print('[SCREEN-SHARE] ✅ Compartición iniciada exitosamente');

        if (mounted) {
          setState(() {
            _isAutoShareActive = true;
            _showScreenShare = true;
          });
        }

        _showSuccess('📺 Pantalla compartida');
      } catch (e) {
        print('[SCREEN-SHARE] ❌ Error en startSharing(): $e');
        _showError('Error al compartir pantalla: $e');
      }
    } catch (e) {
      print('[SCREEN-SHARE] ❌ Error general: $e');
      _showError('Error inesperado: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// ⏹️ Detener compartición de pantalla
  Future<void> _stopScreenShare() async {
    try {
      if (screenController == null) {
        print('[STOP-SHARE] ❌ screenController es null');
        return;
      }
      
      print('[STOP-SHARE] ⏹️ Deteniendo compartición...');
      await screenController!.stopSharing();
      
      print('[STOP-SHARE] ✅ Compartición detenida');
      if (mounted) {
        setState(() {
          _isAutoShareActive = false;
          _showScreenShare = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏹️ Compartición detenida'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('[STOP-SHARE] ❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al detener compartición: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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

            return Center(
              child: Container(
                // 📏 Ventana pequeña adaptable (250x200 base, se adapta al ancho)
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: 300,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.teal, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black,
                ),
                child: Stack(
                  children: [
                    // 📹 CONTENIDO PRINCIPAL (pantalla o cámara)
                    _showScreenShare && _isAutoShareActive
                        ? _buildScreenShareView()
                        : _buildCameraView(),

                    // 🎛️ CONTROLES VERTICALES EN LA DERECHA
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: _buildVerticalControlsBar(),
                    ),

                    // ========== INDICADOR DE COMPARTICIÓN ==========
                    if (screenController != null && _isAutoShareActive)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Compartida',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ========== DIÁLOGO DE CONFIRMACIÓN ==========
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

  /// 🎛️ Barra de controles VERTICAL (sidebar derecha - compacta)
  Widget _buildVerticalControlsBar() {
    return Container(
      width: 50,
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 📹 Toggle Cámara
          _buildVerticalControlButton(
            icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
            label: 'Cam',
            color: _isCameraOn ? Colors.white : Colors.red,
            onPressed: _toggleCamera,
          ),
          const SizedBox(height: 8),

          // 🎤 Toggle Micrófono
          _buildVerticalControlButton(
            icon: _isMicOn ? Icons.mic : Icons.mic_off,
            label: 'Mic',
            color: _isMicOn ? Colors.white : Colors.red,
            onPressed: _toggleMic,
          ),
          const SizedBox(height: 8),

          // 📺 Compartir Pantalla
          _buildVerticalControlButton(
            icon: _isAutoShareActive
                ? Icons.stop_screen_share
                : Icons.screen_share,
            label: 'Share',
            color: _isAutoShareActive ? Colors.orange : Colors.white,
            onPressed: _startScreenShare,
          ),
          const SizedBox(height: 8),

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
          const SizedBox(height: 8),

          // ❌ Salir
          _buildVerticalControlButton(
            icon: Icons.call_end,
            label: 'Exit',
            color: Colors.red,
            onPressed: () {
              _showExitDialog();
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
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.2),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Icon(
                icon,
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
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
