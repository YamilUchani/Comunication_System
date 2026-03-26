// Archivo: student_video_call_screen.dart
// Sistema de videollamada simplificado solo para estudiantes
// - Layout vertical (pantalla arriba, cámara abajo)
// - Mostrar pantalla O cámara, no ambos
// - Controles en la parte inferior: chat, compartir, cámara, micrófono, etc

import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'video_call_controller.dart';
import 'screen_sharing_windows.dart';
import 'video_widgets.dart';
import 'chat/chat_controller.dart';
import 'package:window_manager/window_manager.dart';
import 'whiteboard/whiteboard_overlay.dart'; // Importe de la pizarra
import '../main.dart' as main_module;
import '../services/meeting_cleanup_service.dart';
import '../services/window_service.dart';
import '../services/api_service.dart';
import '../utils/dialog_utils.dart';

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
    this.isPrivateClass = false,
  });

  final int? uid;
  final bool isPrivateClass;

  @override
  _StudentVideoCallScreenState createState() => _StudentVideoCallScreenState();
}

class _StudentVideoCallScreenState extends State<StudentVideoCallScreen>
    with WidgetsBindingObserver, WindowListener {
  late final VideoCallController controller;
  ScreenShareController? screenController;
  ChatController? chatController;
  int? localUid;
  String? _teacherUid; // UID del maestro (primer remoto)
  
  // Estados de controles
  bool _isAutoShareActive = false;
  bool _isCameraOn = true;
  bool _isMicOn = true;
  bool _showChat = false;
  bool _isFullScreen = false;
  bool _isBubbleMode = false;
  bool _showWhiteboard = true;  // 🎨 Control de visibilidad de pizarra (cierre en cascada)
  Size? _preBubbleSize;
  Offset? _preBubblePosition;
  
  bool _isTogglingFullScreen = false; // 🔒 Bloqueo para evitar bugs de clics simultáneos
  RealtimeChannel? _kickChannel; // 📡 Canal para escuchar expulsiones

  void _toggleFullScreen() async {
    if (_isTogglingFullScreen) return;
    _isTogglingFullScreen = true;

    try {
      if (Platform.isWindows) {
        if (_isBubbleMode) await _toggleBubbleMode(); // Salir de burbuja primero
        await windowManager.ensureInitialized();
        final targetState = !_isFullScreen;
        await windowManager.setFullScreen(targetState);
        if (mounted) {
          setState(() {
            _isFullScreen = targetState;
          });
        }
      } else {
        setState(() {
          _isFullScreen = !_isFullScreen;
        });
      }
    } catch (e) {
      print('❌ Error Full Screen: $e');
    } finally {
      if (mounted) {
        _isTogglingFullScreen = false;
      }
    }
  }

  Future<void> _toggleBubbleMode() async {
    if (!Platform.isWindows) return;
    try {
      await windowManager.ensureInitialized();
      
      if (!_isBubbleMode) {
        // 💾 GUARDAR estado actual antes de encoger
        _preBubbleSize = await windowManager.getSize();
        _preBubblePosition = await windowManager.getPosition();
        
        _isBubbleMode = true;
        if (_isFullScreen) {
          _isFullScreen = false;
          await windowManager.setFullScreen(false);
        }
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setSize(const Size(220, 160));
        await windowManager.setPosition(const Offset(40, 40));
      } else {
        // 🔙 RESTAURAR estado anterior
        _isBubbleMode = false;
        await windowManager.setAlwaysOnTop(false);
        if (_preBubbleSize != null) {
          await windowManager.setSize(_preBubbleSize!);
        } else {
          await windowManager.setSize(const Size(850, 520));
        }

        if (_preBubblePosition != null) {
          await windowManager.setPosition(_preBubblePosition!);
        } else {
          await windowManager.center();
        }
      }
      setState(() {});
    } catch (e) {
      print('❌ Error Bubble Mode: $e');
    }
  }

  @override
  void initState() {    
    print('🔴 [StudentVideoCallScreenState] initState() INICIANDO');
    print('🔴 [StudentVideoCallScreen] initState() INICIANDO');
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isWindows) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
    }
    controller = VideoCallController(
      channelName: widget.channelName,
      token: widget.token,
      uid: widget.uid,
      meetingId: widget.meetingId,
      authToken: widget.authToken,
    );
    // 📝 Registrar este controlador para limpieza en logout
    print('📝 [StudentVideoCallScreen] Registrando controlador...');
    MeetingCleanupService.registerActiveController(controller);
    print('✅ [StudentVideoCallScreen] Controlador REGISTRADO exitosamente');
    print('🔴 [StudentVideoCallScreen] Controller creado, llamando _initAgora()');
    _initAgora();
    print('🔴 [StudentVideoCallScreen] _initAgora() llamado, esperando resultado...');
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    print('🚪 Estudiante saliendo de la videollamada...');
    try {
      await MeetingCleanupService.cleanupActiveMeeting(closeWindow: true);
    } catch (e) {
      print('⚠️ Error al salir: $e');
    }
    return AppExitResponse.exit;
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      _showExitDialog();
    }
  }

  Future<void> _initAgora() async {
    try {
      print('[INIT] 🔄 Inicializando Agora...');
      await controller.init();
      print('[INIT] ✅ Agora inicializado');

      if (widget.meetingId != null) {
        await ApiService.setEnteredCallStatus(widget.meetingId!);
        print('[INIT] ✅ Estado actualizado a in_call en backend');
      }
      
      localUid = await _getLocalUid();
      print('[INIT] ✅ Local UID: $localUid');

      if (mounted) {
        setState(() {
          screenController = ScreenShareController(engine: controller.engine);

          // 💬 Inicializar chat con filtro: solo mensajes del maestro
          chatController = ChatController(
            engine: controller.engine,
            localUserId: localUid.toString(),
            localUserName: widget.userName,
            allowedSenderIds: {}, // se puebla cuando el maestro se una
          );
        });
        print('[INIT] ✅ ScreenShareController y ChatController creados');

        // Escuchar cambios en remotos para detectar al maestro
        controller.remoteUids.addListener(_onRemoteUidsChanged);
        // Procesar estado inicial por si ya hay remotos
        _onRemoteUidsChanged();

        // 🚫 Suscribirse a eventos de expulsión
        _subscribeToKick();

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

  /// Actualiza el UID permitido del maestro cuando cambian los remotos
  void _onRemoteUidsChanged() {
    final uids = controller.remoteUids.value;
    if (uids.isNotEmpty) {
      final teacherUidStr = uids.first.toString();
      if (_teacherUid != teacherUidStr) {
        _teacherUid = teacherUidStr;
        chatController?.allowedSenderIds = {teacherUidStr};
        print('[CHAT] 🏫 Maestro detectado: UID=$teacherUidStr');
      }
    }
  }

  /// 🚫 Suscribirse a eventos de expulsión del maestro
  void _subscribeToKick() {
    final meetingId = widget.meetingId;
    if (meetingId == null) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    _kickChannel = Supabase.instance.client
        .channel('meeting:$meetingId')
        .onBroadcast(
          event: 'kick_student',
          callback: (payload) {
            final kickedId = payload['user_id'] as String?;
            if (kickedId == currentUserId && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⛔ El maestro te ha expulsado de la clase'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) _exitMeeting();
              });
            }
          },
        )
        .subscribe();
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
    
    // 🎨 Cerrar pizarra si existe
    if (widget.meetingId != null) {
      try {
        await WindowService().closeWhiteboardWindow(widget.meetingId!);
        print('✅ Pizarra cerrada');
      } catch (e) {
        print('⚠️ La pizarra no estaba abierta o error cerrándola: $e');
      }
    }
    
    // Agregar un pequeño delay para permitir que notifyLeaveChannel se complete
    // antes de descartar los recursos de la pantalla
    try {
      await controller.leaveAndDispose();
      // Esperar un poco más para asegurar que Agora haya procesado la salida
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('Error al salir de la videollamada: $e');
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

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) chatController?.setContext(context);
    });

    return WillPopScope(
      onWillPop: () async {
        if (_isBubbleMode) {
          await _toggleBubbleMode();
          return false;
        }
        if (_isFullScreen) {
          _toggleFullScreen();
          return false;
        }
        _showExitDialog();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isBubbleMode
          ? _buildBubbleUI()
          : Stack(
              children: [
                // Si es pantalla completa, dibujamos primero todo el fondo con el maestro
                if (_isFullScreen)
                  Positioned.fill(child: _buildTeacherArea()),

                // Y si NO es pantalla completa, dibujamos el diseño normal de ventanas
                if (!_isFullScreen) ...[
                // 🎥 Contenido principal centrado
            ValueListenableBuilder<bool>(
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

                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.orange.withOpacity(0.5), width: 2),
                      borderRadius: BorderRadius.circular(20),
                      color: const Color(0xFFF8F9FA), // Gris muy claro
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        // 🎥 Contenido principal (Video Split)
                        Expanded(
                          child: Stack(
                            children: [
                              Column(
                                children: [
                                  Expanded(
                                    child: widget.isPrivateClass 
                                      ? VideoWidgets(
                                          controller: controller,
                                          screenController: screenController,
                                        )
                                      : _buildStudentVideoLayout(),
                                  ),
                                ],
                              ),

                              // === INDICADOR DE COMPARTICIÓN ===
                              if (screenController != null && _isAutoShareActive)
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black26, blurRadius: 4)
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.screen_share, color: Colors.white, size: 14),
                                        SizedBox(width: 8),
                                        Text(
                                          'Transmitiendo',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
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

                        // 🎛️ CONTROLES VERTICALES EN LA DERECHA
                        if (!_isFullScreen) _buildVerticalControlsBar(),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // 💬 Panel de chat deslizable (desde la derecha)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              right: _showChat ? 0 : -320,
              top: 0,
              bottom: 0,
              width: 320,
              child: Material(
                elevation: 8,
                color: const Color(0xFF1A1A2E),
                child: _buildStudentChatPanel(),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}


  // ========== DIÁLOGOS DE CONFIRMACIÓN ==========
  void _showReturnDialog() {
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
                  '¿Volver a la sala de espera?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Cancelar', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _returnToWaitingRoom();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Volver', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
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

  Future<void> _returnToWaitingRoom() async {
    print('🚪 Retornando a la sala de espera...');
    try {
      if (_isAutoShareActive) {
        await _stopScreenShare();
      }
      
      // Desconectar recursos pero NO cerrar la app entera aún
      await controller.leaveAndDispose();
      if (widget.meetingId != null) {
        await ApiService.setBackToWaitingRoomStatus(widget.meetingId!);
      }
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (main_module.isSecondaryWindow) {
        // Lanzar la sala de espera con los mismos datos
        await WindowService().openWaitingRoomWindow(
          channelName: widget.channelName,
          token: widget.token,
          userName: widget.userName,
          meetingTitle: 'Reunión en progreso',
          meetingId: widget.meetingId,
          authToken: widget.authToken,
        );
        
        // Matar el proceso actual de videollamada
        await Future.delayed(const Duration(milliseconds: 200));
        exit(0);
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      print('⚠️ Error al volver a sala de espera: $e');
    }
  }

  void _showExitDialog() async {
    final confirmed = await DialogUtils.showExitMeetingDialog(context);
    if (confirmed && mounted) {
      _exitMeeting();
    }
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

  Widget _buildStudentVideoLayout() {
    return Column(
      children: [
        // 🎓 MAESTRO - Parte superior (40%)
        Expanded(
          flex: 2, // 40% del espacio
          child: _buildTeacherArea(),
        ),
        
        // Divisor
        Container(
          height: 2,
          color: Colors.grey[200]!.withOpacity(0.5),
        ),
        
        // 👨‍🎓 ESTUDIANTE - Parte inferior (40%)
        Expanded(
          flex: 2, // 40% del espacio
          child: Container(
            color: Colors.white,
            child: ValueListenableBuilder<bool>(
              valueListenable: controller.localUserJoined,
              builder: (context, joined, _) {
                if (!joined) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  );
                }
                
                // Mostrar indicador de pantalla compartida o el ícono de cámara
                if (_isAutoShareActive) {
                  // 📺 Indicador compacto de pantalla compartida
                  return Container(
                    color: Colors.white,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Compartiendo pantalla',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Los demás ven tu pantalla',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // 🎥 Vista normal: ícono de cámara + etiqueta
                return Stack(
                  children: [
                    Center(
                      child: Icon(
                        _isCameraOn ? Icons.videocam : Icons.videocam_off,
                        size: 60,
                        color: _isCameraOn ? Colors.orange : Colors.red[300],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Tú',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        
        // 🚦 Botones de estatus (Semáforo) - Estilo Dashboard
        _buildStatusButtonsRow(),
      ],
    );
  }

  /// 🎓 Área del maestro (Video o Pantalla compartida)
  Widget _buildTeacherArea() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
            Positioned.fill(
              child: ValueListenableBuilder<Set<int>>(
                valueListenable: controller.remoteUids,
          builder: (context, remoteUids, _) {
            return ValueListenableBuilder<Set<int>>(
              valueListenable: controller.remoteScreenShareUids,
              builder: (context, screenShareUids, _) {
                // Si hay pantalla compartida, mostrarla
                if (screenShareUids.isNotEmpty) {
                  return Container(
                    color: Colors.black,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.8, end: 1.2),
                          duration: const Duration(milliseconds: 1000),
                          onEnd: () {},
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Icon(
                                Icons.videocam,
                                size: 80,
                                color: Colors.orange.withOpacity(0.9),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '📺 Pantalla Compartida',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'El maestro está compartiendo su pantalla',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'En directo',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }
                
                // Si no hay pantalla compartida, mostrar el maestro
                if (remoteUids.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Esperando al maestro...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                // Mostrar el video del primer maestro (usualmente el único remoto)
                final teacherUid = remoteUids.first;
                return Stack(
                  children: [
                    // 🎥 Video del maestro con detección de frames congelados
                    RemoteVideoWithFrozenDetection(
                      uid: teacherUid,
                      channelName: controller.channelName,
                      rtcEngine: controller.engine,
                    ),
                    // Etiqueta del maestro
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Maestro',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
          
          // 🎨 PIZARRA DEL PROFESOR (en tiempo real)
          if (widget.meetingId != null && _showWhiteboard)
            Positioned.fill(
              child: IgnorePointer( // El estudiante solo ve, no dibuja ni interactúa para evitar bugs de clicks
                child: WhiteboardOverlay(
                  isTeacher: false,
                  meetingId: widget.meetingId!,
                  onClose: () {
                    // 🚪 Cuando maestro cierra pizarra (evento close_board)
                    setState(() => _showWhiteboard = false);
                    print('🚪 [Estudiante] Pizarra cerrada. Overlay oculto.');
                  },
                ),
              ),
            ),

          // 🔲 BOTON MAXIMIZAR SIEMPRE VISIBLE
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
                tooltip: _isFullScreen ? 'Salir de Pantalla Completa' : 'Pantalla Completa',
                onPressed: _toggleFullScreen,
              ),
            ),
          ),
        ]),
    );
  }

  /// Fila de botones de estatus (rojo, amarillo, verde)
  Widget _buildStatusButtonsRow() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatusButton(Colors.red[400]!, 'No entiendo nada', '🔴'),
          const SizedBox(width: 10),
          _buildStatusButton(Colors.orange[400]!, 'No entiendo algo', '🟡'),
          const SizedBox(width: 10),
          _buildStatusButton(Colors.green[400]!, 'Entiendo todo', '🟢'),
        ],
      ),
    );
  }

  Widget _buildStatusButton(Color color, String text, String icon) {
    return Expanded(
      child: InkWell(
        onTap: () {
          chatController?.sendTextMessage(
            text, 
            recipientId: _teacherUid, 
            recipientName: 'Maestro'
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Estatus enviado: $text'),
              duration: const Duration(seconds: 1),
              backgroundColor: color,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(100), // Stadium
            border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text.split(' ').last,
                  style: TextStyle(
                    color: color.withAlpha(200),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
      width: 85,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 📹 Toggle Cámara
              _buildVerticalControlButton(
                icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                label: 'Cámara',
                color: _isCameraOn ? Colors.orange : Colors.grey[600]!,
                onPressed: _toggleCamera,
              ),
              const SizedBox(height: 12),

              // 🎤 Toggle Micrófono
              _buildVerticalControlButton(
                icon: _isMicOn ? Icons.mic : Icons.mic_off,
                label: 'Micro',
                color: _isMicOn ? Colors.orange : Colors.grey[600]!,
                onPressed: _toggleMic,
              ),
              const SizedBox(height: 12),

              // 🫧 Modo Burbuja (PiP)
              _buildVerticalControlButton(
                icon: _isBubbleMode ? Icons.picture_in_picture_alt : Icons.picture_in_picture,
                label: 'Burbuja',
                color: _isBubbleMode ? Colors.orange : Colors.grey[600]!,
                onPressed: _toggleBubbleMode,
              ),
              const SizedBox(height: 12),

              // 📺 Compartir Pantalla
              _buildVerticalControlButton(
                icon: _isAutoShareActive
                    ? Icons.stop_screen_share
                    : Icons.screen_share,
                label: 'Espejo',
                color: _isAutoShareActive ? Colors.deepPurple : Colors.grey[600]!,
                onPressed: _startScreenShare,
              ),
              const SizedBox(height: 12),

              // 💬 Chat
              ValueListenableBuilder<bool>(
                valueListenable: chatController?.hasUnreadMessages ?? ValueNotifier(false),
                builder: (context, hasUnread, _) {
                  return _buildVerticalControlButton(
                    icon: hasUnread ? Icons.chat : Icons.chat_bubble_outline,
                    label: 'Chat',
                    color: _showChat ? Colors.deepPurple : (hasUnread ? Colors.orange : Colors.grey[600]!),
                    onPressed: () {
                      setState(() {
                        _showChat = !_showChat;
                      });
                      if (_showChat) chatController?.markMessagesAsRead();
                    },
                  );
                },
              ),
              
              const SizedBox(height: 12),

              // 🚪 Volver a sala de espera
              _buildVerticalControlButton(
                icon: Icons.meeting_room,
                label: 'Volver',
                color: Colors.orange[400]!,
                onPressed: () {
                  _showReturnDialog();
                },
              ),

              const SizedBox(height: 12),

              // ❌ Salir
              _buildVerticalControlButton(
                icon: Icons.exit_to_app,
                label: 'Salir',
                color: Colors.red[400]!,
                onPressed: () {
                  _showExitDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 💬 PANEL DE CHAT DEL ESTUDIANTE
  // ============================================================
  Widget _buildStudentChatPanel() {
    if (chatController == null) {
      return const Center(
        child: Text('Chat no disponible', style: TextStyle(color: Colors.white54)),
      );
    }

    return _StudentChatPanel(
      chatController: chatController!,
      teacherUid: _teacherUid,
      onClose: () => setState(() { _showChat = false; }),
    );
  }

  /// Botón de control VERTICAL individual
  Widget _buildVerticalControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        width: double.infinity,
        color: Colors.transparent, // Para que el GestureDetector capture todo el ancho
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
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color == Colors.grey[600] ? Colors.grey[500] : color,
                fontSize: 11,
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
    _kickChannel?.unsubscribe();
    if (Platform.isWindows) {
      if (_isFullScreen) windowManager.setFullScreen(false);
      if (_isBubbleMode) {
        windowManager.setAlwaysOnTop(false);
        windowManager.setSize(const Size(850, 520));
      }
      windowManager.removeListener(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    controller.remoteUids.removeListener(_onRemoteUidsChanged);
    // Desregistrar para que no intente limpiar si ya se limpió
    print('📝 [StudentVideoCallScreen] Desregistrando controlador en dispose...');
    MeetingCleanupService.unregisterActiveController();
    print('✅ [StudentVideoCallScreen] Controlador DESREGISTRADO en dispose');
    controller.dispose();
    screenController?.dispose();
    chatController?.dispose();
    super.dispose();
  }

  /// 🫧 UI de Burbuja (Picture in Picture)
  Widget _buildBubbleUI() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: _buildTeacherArea()),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggleBubbleMode,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.open_in_full, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 💬 Widget del panel de chat del estudiante (privado maestro-estudiante)
// ============================================================
class _StudentChatPanel extends StatefulWidget {
  final ChatController chatController;
  final String? teacherUid;
  final VoidCallback onClose;

  const _StudentChatPanel({
    required this.chatController,
    required this.teacherUid,
    required this.onClose,
  });

  @override
  State<_StudentChatPanel> createState() => _StudentChatPanelState();
}

class _StudentChatPanelState extends State<_StudentChatPanel> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.chatController.messages.addListener(_onNewMessage);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _onNewMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Siempre enviar al maestro (privado)
    widget.chatController.sendTextMessage(
      text,
      recipientId: widget.teacherUid,
      recipientName: 'Maestro',
    ).then((_) {
      _textController.clear();
      _scrollToBottom();
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    });
  }

  Widget _buildBubble(message) {
    final isMe = message.senderId == widget.chatController.localUserId;
    final time =
        '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.orange,
              child: const Text(
                'M',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF00BCD4)   // teal para el estudiante
                    : const Color(0xFF2D2D4E), // oscuro para el maestro
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    const Text(
                      'Maestro',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    message.content,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F23),
            border: Border(
              bottom: BorderSide(color: Color(0xFF2D2D4E), width: 1),
            ),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.orange,
                child: Text(
                  'M',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maestro',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Chat privado',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: widget.onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),

        // Lista de mensajes
        Expanded(
          child: ValueListenableBuilder<List<dynamic>>(
            valueListenable: widget.chatController.messages,
            builder: (context, messages, _) {
              if (messages.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          color: Colors.white24, size: 40),
                      SizedBox(height: 12),
                      Text(
                        'Sin mensajes aún.\nEscribe algo al maestro.',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: messages.length,
                itemBuilder: (_, i) => _buildBubble(messages[i]),
              );
            },
          ),
        ),
        
        // Emojis de reacción (Igual que el maestro)
        _buildReactionRow(),

        // Input
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F23),
            border: Border(
              top: BorderSide(color: Color(0xFF2D2D4E), width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Escribe al maestro...',
                    hintStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2D2D4E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00BCD4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    widget.chatController.messages.removeListener(_onNewMessage);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Fila de reacciones rápidas
  Widget _buildReactionRow() {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F23),
        border: Border(
          top: BorderSide(color: Color(0xFF2D2D4E), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildEmojiButton('👍', 'like'),
          _buildEmojiButton('👋', 'hand'),
          _buildEmojiButton('👏', 'clap'),
          _buildEmojiButton('❤️', 'heart'),
          _buildEmojiButton('🔥', 'fire'),
        ],
      ),
    );
  }

  Widget _buildEmojiButton(String emoji, String type) {
    return InkWell(
      onTap: () => widget.chatController.sendReaction(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

