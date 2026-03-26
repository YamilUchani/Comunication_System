// Archivo: video_call_screen.dart

import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'video_call_controller.dart';
import 'video_widgets.dart';
import 'controls_bar.dart';
import 'screen_sharing_windows.dart';
import '../main.dart' as main_module;
import 'chat/chat_screen.dart';
import 'chat/chat_controller.dart';
import 'device_manager.dart'; // Importa el DeviceManager
import '../services/window_service.dart'; // Importa WindowService
import '../services/meeting_cleanup_service.dart';
import 'package:window_manager/window_manager.dart';
import '../services/api_service.dart';
import 'dart:async';

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

class _VideoCallScreenState extends State<VideoCallScreen> with WidgetsBindingObserver, WindowListener {
  late final VideoCallController controller;
  ScreenShareController? screenController;
  late ChatController chatController;
  DeviceManager? deviceManager; // Ahora es nullable
  final Map<String, String> users = {};
  int? localUid;
  bool _showChat = false; // 💬 Control de visibilidad del chat
  bool _showStudents = false; // 👥 Control de visibilidad de lista de estudiantes
  List<dynamic> _studentsList = [];
  Timer? _studentsTimer;
  bool _whiteboardOpen = false; // 🎨 Trackea si la pizarra está abierta
  RealtimeChannel? _notificationsChannel; // 📡 Canal para notificaciones en tiempo real
  
  // 🫧 Bubble mode para maestro/admin (minimizar ventana)
  bool _isBubbleMode = false;
  Size? _preBubbleSize;
  Offset? _preBubblePosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isWindows) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true); // Evitar cierre directo con la 'X'
    }
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

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      _showExitDialog();
    }
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
        _subscribeToStudentCalls();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al inicializar la llamada: $e')),
        );
      }
    }
  }

  /// 📡 Suscribirse a llamadas de estudiantes via Supabase Realtime
  void _subscribeToStudentCalls() {
    final meetingId = widget.meetingId;
    if (meetingId == null) return;

    _notificationsChannel = Supabase.instance.client
        .channel('meeting:$meetingId')
        .onBroadcast(
          event: 'student_calling',
          callback: (payload) {
            final studentName = payload['student_name'] as String? ?? 'Un estudiante';
            if (mounted) {
              _showStudentCallingNotification(studentName);
            }
          },
        )
        .subscribe();
  }

  /// 🔔 Mostrar notificación tipo banner cuando un estudiante llama
  void _showStudentCallingNotification(String studentName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.indigo[700],
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            const Icon(Icons.phone_in_talk, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '📞 $studentName quiere entrar a la clase\nRevisa la lista de miembros para unirlo.',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🚫 Expulsar a un estudiante del canal via Realtime
  Future<void> _kickStudent(dynamic student) async {
    final meetingId = widget.meetingId;
    if (meetingId == null) return;

    final studentName = student['name'] ?? 'Estudiante';
    final userId = student['user_id'] as String?;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .channel('meeting:$meetingId')
          .sendBroadcastMessage(
            event: 'kick_student',
            payload: {'user_id': userId},
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⛔ $studentName ha sido expulsado'),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error al expulsar estudiante: $e');
    }
  }

  /// ✅ Admitir a un estudiante a la clase via Realtime
  Future<void> _admitStudent(dynamic student) async {
    final meetingId = widget.meetingId;
    if (meetingId == null) return;

    final studentName = student['name'] ?? 'Estudiante';
    final userId = student['user_id'] as String?;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .channel('meeting:$meetingId')
          .sendBroadcastMessage(
            event: 'admit_student',
            payload: {'user_id': userId},
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $studentName ha sido admitido a la clase'),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error al admitir estudiante: $e');
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
      if (_showChat) _showStudents = false; // Cerrar el otro panel
    });
    if (_showChat) {
      chatController.markMessagesAsRead();
    }
  }

  /// 👥 Toggle para mostrar/ocultar lista de estudiantes
  void _toggleStudents() {
    setState(() {
      _showStudents = !_showStudents;
      if (_showStudents) {
        _showChat = false; // Cerrar chat si se abre alumnos
        _fetchStudentsStatus();
        _studentsTimer = Timer.periodic(const Duration(seconds: 3), (_) {
          _fetchStudentsStatus();
        });
      } else {
        _studentsTimer?.cancel();
      }
    });
  }

  Future<void> _fetchStudentsStatus() async {
    if (widget.meetingId == null || !mounted || !_showStudents) return;
    try {
      final statuses = await ApiService.getStudentsStatus(widget.meetingId!);
      if (mounted) {
        setState(() {
          _studentsList = statuses;
        });
      }
    } catch (e) {
      print('⚠️ Error al obtener estados de alumnos: $e');
    }
  }

  /// 🎨 Monitorea si la pizarra se cierra para actualizar el estado
  Future<void> _monitorWhiteboardClosure() async {
    if (widget.meetingId == null) return;
    
    // 🔄 Polling: Verificar cada 500ms si la pizarra sigue abierta
    final checkInterval = Duration(milliseconds: 500);
    int maxAttempts = 0;
    
    while (_whiteboardOpen && mounted && maxAttempts < 100000) {
      await Future.delayed(checkInterval);
      
      // Si WindowService reporta que la pizarra NO está abierta, actualizar estado
      if (!WindowService().isWhiteboardOpen(widget.meetingId!)) {
        if (mounted) {
          setState(() => _whiteboardOpen = false);
          print('✅ Pizarra cerrada detectada. Estado actualizado.');
        }
        break;
      }
      maxAttempts++;
    }
  }

  /// 🫧 Toggle bubble mode (minimizar/expandir ventana)
  Future<void> _toggleBubbleMode() async {
    if (!Platform.isWindows) return;
    try {
      await windowManager.ensureInitialized();
      
      if (!_isBubbleMode) {
        // 💾 GUARDAR estado actual antes de encoger
        _preBubbleSize = await windowManager.getSize();
        _preBubblePosition = await windowManager.getPosition();
        
        _isBubbleMode = true;
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
          await windowManager.setSize(const Size(1000, 700));
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

  /// ❌ Salir de la videollamada
  Future<void> _exitMeeting() async {
    print('🚪 Saliendo de la videollamada...');
    
    try {
      // 🎨 Cerrar pizarra si existe
      if (widget.meetingId != null) {
        try {
          await WindowService().closeWhiteboardWindow(widget.meetingId!);
          print('✅ Pizarra cerrada');
        } catch (e) {
          print('⚠️ La pizarra no estaba abierta o error cerrándola: $e');
        }
      }
      
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
        if (_isBubbleMode) {
          await _toggleBubbleMode();
          return false;
        }
        _showExitDialog();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isBubbleMode ? _buildBubbleUI() : ValueListenableBuilder<bool>(
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
                
                // 👥 Panel de Estudiantes desplegable a la derecha
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  right: _showStudents ? 0 : -350,
                  top: 0,
                  bottom: 0,
                  width: 350,
                  child: Material(
                    color: Colors.grey[900],
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.black45,
                              child: const Text(
                                'Lista de Estudiantes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _studentsList.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Obteniendo lista...',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _studentsList.length,
                                    itemBuilder: (context, index) {
                                      final student = _studentsList[index];
                                      final status = student['status']; // 'waiting', 'in_call', 'absent', 'left'
                                      
                                      Color dotColor;
                                      String statusText;
                                      switch (status) {
                                        case 'in_call':
                                          dotColor = Colors.green;
                                          statusText = 'En clase';
                                          break;
                                        case 'waiting':
                                          dotColor = Colors.orange;
                                          statusText = 'Sala de espera';
                                          break;
                                        case 'left':
                                          dotColor = Colors.red;
                                          statusText = 'Salió';
                                          break;
                                        default:
                                          dotColor = Colors.grey;
                                          statusText = 'Ausente';
                                      }

                                      final canKick = status == 'in_call' || status == 'waiting';
                                      final canAdmit = status == 'waiting';

                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.white10,
                                          child: Icon(Icons.person, color: Colors.white54),
                                        ),
                                        title: Text(
                                          student['name'] ?? 'Desconocido',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                        subtitle: Row(
                                          children: [
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: dotColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              statusText,
                                              style: TextStyle(color: dotColor, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (canAdmit)
                                              IconButton(
                                                icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                                                tooltip: 'Admitir a la clase',
                                                onPressed: () => _admitStudent(student),
                                              ),
                                            if (canKick)
                                              IconButton(
                                                icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                                                tooltip: 'Expulsar',
                                                onPressed: () => _kickStudent(student),
                                              ),
                                            IconButton(
                                              icon: const Icon(Icons.assignment_turned_in, color: Colors.tealAccent),
                                              tooltip: 'Evaluar Estudiante',
                                              onPressed: () => _showAttendanceAndAchievementsDialog(student),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                            ),
                          ],
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
                              onPressed: _toggleStudents,
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
              onToggleStudents: _toggleStudents,
              onToggleWhiteboard: () {
                if (_whiteboardOpen) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('La pizarra ya está abierta')),
                  );
                  return;
                }
                if (widget.meetingId != null) {
                  setState(() => _whiteboardOpen = true);
                  WindowService()
                      .openWhiteboardWindow(
                        meetingId: widget.meetingId!,
                        isTeacher: true,
                      )
                      .then((_) {
                    _monitorWhiteboardClosure();
                  }).catchError((e) {
                    setState(() => _whiteboardOpen = false);
                    print('Error al abrir pizarra: $e');
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No hay reunión activa para iniciar la pizarra')),
                  );
                }
              },
              onToggleBubbleMode: _toggleBubbleMode, // 🫧 Pasar callback para minimizar
            );
          },
        ),
      ),
    );
  }

  /// 🫧 Construir UI en modo burbuja (ventana minimizada)
  Widget _buildBubbleUI() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Mostrar el widget de videos principal
          Positioned.fill(
            child: ValueListenableBuilder<bool>(
              valueListenable: controller.localUserJoined,
              builder: (context, joined, _) {
                if (!joined) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  );
                }
                return VideoWidgets(
                  controller: controller,
                );
              },
            ),
          ),
          // Botón para expandir
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

  void _showAttendanceAndAchievementsDialog(dynamic student) async {
    final studentId = student['user_id'];
    final studentName = student['name'] ?? 'Estudiante';
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    String? attendanceId;
    List<dynamic> allAchievements = [];
    List<dynamic> currentAchievementsList = [];

    try {
      // 1. Guardar o asegurar asistencia de hoy
      final records = await ApiService.recordAttendance(
        meetingDate: todayStr,
        studentIds: [studentId],
        meetingId: widget.meetingId,
        notes: 'Registro desde la clase virtual',
      );
      if (records.isNotEmpty) {
        attendanceId = records[0]['id'];
      }

      // 2. Obtener la lista general de logros
      allAchievements = await ApiService.getAchievements();

      // 3. Obtener los logros del alumno en ESTA sesión
      if (attendanceId != null) {
        final res = await Supabase.instance.client
            .from('student_achievements')
            .select('*')
            .eq('attendance_id', attendanceId);
        currentAchievementsList = res as List<dynamic>;
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // cerrar loader
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      return;
    }

    if (!mounted) return;
    Navigator.pop(context); // cerrar loader

    if (attendanceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo obtener la asistencia')));
      return;
    }

    Set<String> unlockedAchievementIds = currentAchievementsList.map((e) => e['achievement_id'] as String).toSet();

    // Diálogo con los checkboxes listos
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Evaluación: $studentName'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Asistencia del día guardada exitosamente.', style: TextStyle(color: Colors.green)),
                    const SizedBox(height: 15),
                    const Text('Otorgar logros a este estudiante en la clase actual:'),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allAchievements.length,
                        itemBuilder: (context, index) {
                          final ach = allAchievements[index];
                          final achId = ach['id'] as String;
                          final isUnlocked = unlockedAchievementIds.contains(achId);

                          return CheckboxListTile(
                            title: Text('${ach['icon']} ${ach['name']}'),
                            subtitle: Text(ach['description'] ?? '', style: const TextStyle(fontSize: 12)),
                            value: isUnlocked,
                            onChanged: (val) async {
                              // Optimistic UI update
                              setModalState(() {
                                if (val == true) unlockedAchievementIds.add(achId);
                                else unlockedAchievementIds.remove(achId);
                              });

                              try {
                                if (val == true) {
                                  // Agregar
                                  await ApiService.assignAchievementsToAttendance(attendanceId!, [achId]);
                                } else {
                                  // Remover (directo)
                                  await Supabase.instance.client
                                      .from('student_achievements')
                                      .delete()
                                      .eq('student_id', studentId)
                                      .eq('achievement_id', achId)
                                      .eq('attendance_id', attendanceId!);
                                }
                              } catch (e) {
                                setModalState(() {
                                  if (val == true) unlockedAchievementIds.remove(achId);
                                  else unlockedAchievementIds.add(achId);
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cambiar logro: $e')));
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Completado'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _studentsTimer?.cancel();
    _notificationsChannel?.unsubscribe();
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    // leaveAndDispose ya fue llamado en _exitMeeting() o didRequestAppExit()
    // controller.dispose() ahora es sincrónico y seguro llamar múltiples veces
    controller.dispose();
    screenController?.dispose();
    chatController.dispose();
    super.dispose();
  }
}
