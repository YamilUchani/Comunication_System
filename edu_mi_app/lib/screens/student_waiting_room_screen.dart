import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:async';
import 'package:window_manager/window_manager.dart';
import '../services/window_service.dart';
import '../services/api_service.dart';

class StudentWaitingRoomScreen extends StatefulWidget {
  final String channelName;
  final String token;
  final String userName;
  final String meetingTitle;
  final String? meetingId;
  final String? authToken;
  final bool isPrivateClass;

  const StudentWaitingRoomScreen({
    super.key,
    required this.channelName,
    required this.token,
    required this.userName,
    required this.meetingTitle,
    this.meetingId,
    this.authToken,
    this.isPrivateClass = false,
  });

  @override
  State<StudentWaitingRoomScreen> createState() =>
      _StudentWaitingRoomScreenState();
}

class _StudentWaitingRoomScreenState extends State<StudentWaitingRoomScreen> with WindowListener {
  bool _isJoining = false;
  bool _isMinimized = false;
  Size _originalWindowSize = const Size(250, 200);
  Offset _originalWindowPosition = const Offset(20, 20);
  Offset _bubblePosition = const Offset(10, 10);
  Offset _dragStart = Offset.zero;
  bool _isCoolingDown = false; // Evitar spam de llamadas
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true); // Evitar cierre directo con la 'X'
    }
    _initializeWindow();
    _setupRealtimeSubscription();
    
    // Explicitamente reportar a la BD que entramos a sala de espera
    if (widget.meetingId != null) {
      ApiService.setBackToWaitingRoomStatus(widget.meetingId!);
    }
  }

  void _setupRealtimeSubscription() {
    final meetingId = widget.meetingId;
    if (meetingId == null) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    _realtimeChannel = Supabase.instance.client
        .channel('meeting:$meetingId')
        .onBroadcast(
          event: 'kick_student',
          callback: (payload) {
            final kickedId = payload['user_id'] as String?;
            if (kickedId == currentUserId && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⛔ El maestro te ha removido de la sala de espera'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
              Future.delayed(const Duration(seconds: 1), () => exit(0));
            }
          },
        )
        .onBroadcast(
          event: 'admit_student',
          callback: (payload) {
            final admittedId = payload['user_id'] as String?;
            if (admittedId == currentUserId && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ El maestro te ha admitido a la clase'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
              // Entrar automáticamente
              _joinMeeting();
            }
          },
        )
        .onBroadcast(
          event: 'meeting_ended',
          callback: (payload) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('La clase ha sido finalizada por el maestro.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
              Future.delayed(const Duration(seconds: 2), () => exit(0));
            }
          },
        )
        .subscribe((status, error) {
          if (status == 'SUBSCRIBED') {
            print('✅ Suscrito al canal de reunión. Enviando señal de presencia...');
            _callTeacher(isAuto: true);
          }
        });
  }

  Future<void> _callTeacher({bool isAuto = false}) async {
    if (_isCoolingDown && !isAuto) return;
    final meetingId = widget.meetingId;
    if (meetingId == null) return;

    if (!isAuto) setState(() => _isCoolingDown = true);

    try {
      print('📡 Enviando señal student_calling (auto: $isAuto)');
      await Supabase.instance.client
          .channel('meeting:$meetingId')
          .sendBroadcastMessage(
            event: 'student_calling',
            payload: {
              'student_name': widget.userName,
              'user_id': Supabase.instance.client.auth.currentUser?.id ?? '',
              'is_auto': isAuto,
            },
          );

      if (mounted && !isAuto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📞 Notificación enviada al maestro'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Update BD explicitly for teacher's heartbeat list
      ApiService.setBackToWaitingRoomStatus(meetingId);
      
    } catch (e) {
      print('❌ Error al llamar al maestro: $e');
    }

    if (!isAuto) {
      // Cooldown de 5 segundos para evitar spam (solo si es manual)
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) setState(() => _isCoolingDown = false);
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      _showExitDialog();
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
                  '¿Salir completamente de la clase?',
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
                          exit(0);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Salir', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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

  Future<void> _initializeWindow() async {
    if (!Platform.isWindows) return;
    
    try {
      await windowManager.ensureInitialized();
      final size = await windowManager.getSize();
      final position = await windowManager.getPosition();
      
      setState(() {
        _originalWindowSize = size;
        _originalWindowPosition = position;
      });
    } catch (e) {
      print('Error inicializando window manager: $e');
    }
  }

  Future<void> _expandFromBubble() async {
    if (!Platform.isWindows) {
      setState(() => _isMinimized = false);
      return;
    }

    try {
      await windowManager.setSize(_originalWindowSize);
      await windowManager.setPosition(_originalWindowPosition);
      setState(() => _isMinimized = false);
    } catch (e) {
      print('Error expandiendo ventana: $e');
    }
  }

  void _onBubbleDragUpdate(DragUpdateDetails details) {
    final newPosition = _bubblePosition + details.delta;
    setState(() => _bubblePosition = newPosition);
  }

  Future<void> _joinMeeting() async {
    setState(() => _isJoining = true);

    try {
      print('🚀 Estudiante entrando a videollamada desde sala de espera...');

      await WindowService().openVideoCallWindow(
        channelName: widget.channelName,
        token: widget.token,
        userName: widget.userName,
        userRole: 'student', // 🎓 Indicar que es estudiante para usar StudentVideoCallScreen
        meetingId: widget.meetingId,
        authToken: widget.authToken,
        windowWidth: 300,
        windowHeight: 900,
        isPrivateClass: widget.isPrivateClass,
      );

      if (widget.meetingId != null) {
        // Enforce the in_call state in DB immediately
        await ApiService.setEnteredCallStatus(widget.meetingId!);
      }

      // Cerrar la ventana de sala de espera después de abrir la videollamada
      print('🔴 Cerrando ventana de sala de espera...');
      exit(0);
    } catch (e) {
      print('❌ Error al entrar a la reunión: $e');
      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si está minimizado, mostrar solo el bubble flotante
    if (_isMinimized) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Bubble flotante arrastrable
            Positioned(
              top: _bubblePosition.dy,
              left: _bubblePosition.dx,
              child: GestureDetector(
                onTap: _expandFromBubble,
                onPanUpdate: _onBubbleDragUpdate,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.hourglass_bottom,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Vista normal si no está minimizado - Pequeño rectangulo flotante
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              width: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF212121),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Título reunión
                  Text(
                    widget.meetingTitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Nombre estudiante
                  Text(
                    widget.userName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Fila de botones flotantes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Botón de llamada al maestro
                      GestureDetector(
                        onTap: _isCoolingDown ? null : _callTeacher,
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isCoolingDown
                                ? Colors.blue[300]
                                : Colors.blue[700],
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isCoolingDown ? Icons.hourglass_top : Icons.phone,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),

                      // Botón de entrar
                      GestureDetector(
                        onTap: _isJoining ? null : _joinMeeting,
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isJoining
                                ? const Color(0xFFFFA500).withOpacity(0.7)
                                : Colors.orange,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: _isJoining
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.videocam,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
