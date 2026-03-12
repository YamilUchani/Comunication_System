import 'dart:io';
import 'dart:convert';

class WindowService {
  static final WindowService _instance = WindowService._internal();
  factory WindowService() => _instance;
  WindowService._internal();

  final List<Process> _spawnedProcesses = [];

  /// Abre una nueva ventana de sala de espera para el estudiante.
  /// 
  /// [channelName]: Nombre del canal de Agora.
  /// [token]: Token de acceso Agora.
  /// [userName]: Nombre del estudiante.
  /// [meetingTitle]: Título de la reunión.
  /// [meetingId]: ID de la reunión para heartbeat.
  /// [authToken]: Token de autenticación de Supabase.
  Future<void> openWaitingRoomWindow({
    required String channelName,
    required String token,
    required String userName,
    required String meetingTitle,
    String? meetingId,
    String? authToken,
  }) async {
    final String executablePath = Platform.resolvedExecutable;
    
    // Argumentos para la nueva instancia
    final List<String> args = [
      '--secondary',
      '--mode=waiting-room',
      '--channel=$channelName',
      '--token=$token',
      '--user=$userName',
      '--meetingTitle=$meetingTitle',
      if (meetingId != null) '--meetingId=$meetingId',
      if (authToken != null) '--authToken=$authToken',
    ];

    print('🚀 Iniciando ventana secundaria de sala de espera...');
    print('   CMD: $executablePath ${args.join(' ')}');

    try {
      final process = await Process.start(executablePath, args);
      
      // ✅ PIPEO DE LOGS
      process.stdout.transform(utf8.decoder).listen((data) {
        stdout.write('[CHILD-OUT] $data');
      });
      process.stderr.transform(utf8.decoder).listen((data) {
        stderr.write('[CHILD-ERR] $data');
      });

      _spawnedProcesses.add(process);

      // Limpiar de la lista si el proceso termina solo
      process.exitCode.then((_) => _spawnedProcesses.remove(process));
      
      print('   ✅ Ventana iniciada con PID: ${process.pid}');
    } catch (e) {
      print('   ❌ Error al iniciar ventana secundaria: $e');
      rethrow;
    }
  }

  /// Abre una nueva ventana de videollamada.
  /// 
  /// [channelName]: Nombre del canal de Agora.
  /// [token]: Token de acceso Agora.
  /// [userName]: Nombre del usuario.
  /// [userRole]: Rol del usuario ('student', 'teacher', or 'admin'). Define qué pantalla mostrar.
  /// [meetingId]: ID de la reunión para heartbeat.
  /// [authToken]: Token de autenticación de Supabase.
  /// [windowWidth]: Ancho de la ventana (opcional, por defecto es dinámico).
  /// [windowHeight]: Altura de la ventana (opcional, por defecto es dinámico).
  Future<void> openVideoCallWindow({
    required String channelName,
    required String token,
    required String userName,
    String userRole = 'teacher', // 'student', 'teacher', 'admin'
    String? meetingId,
    String? authToken,
    int uid = 0,
    int? windowWidth,
    int? windowHeight,
  }) async {
    final String executablePath = Platform.resolvedExecutable;
    
    // Argumentos para la nueva instancia
    final List<String> args = [
      '--secondary',
      '--mode=video-call',
      '--channel=$channelName',
      '--token=$token',
      '--user=$userName',
      '--userRole=$userRole',
      '--uid=$uid',
      if (meetingId != null) '--meetingId=$meetingId',
      if (authToken != null) '--authToken=$authToken',
      if (windowWidth != null) '--windowWidth=$windowWidth',
      if (windowHeight != null) '--windowHeight=$windowHeight',
    ];

    print('🚀 Iniciando ventana secundaria de videollamada...');
    print('   CMD: $executablePath ${args.join(' ')}');

    try {
      final process = await Process.start(executablePath, args);
      
      // ✅ PIPEO DE LOGS: Esto nos permitirá ver qué pasa dentro de la ventana del maestro
      process.stdout.transform(utf8.decoder).listen((data) {
        stdout.write('[CHILD-OUT] $data');
      });
      process.stderr.transform(utf8.decoder).listen((data) {
        stderr.write('[CHILD-ERR] $data');
      });

      _spawnedProcesses.add(process);

      // Limpiar de la lista si el proceso termina solo
      process.exitCode.then((_) => _spawnedProcesses.remove(process));
      
      print('   ✅ Ventana iniciada con PID: ${process.pid}');
    } catch (e) {
      print('   ❌ Error al iniciar ventana secundaria: $e');
      rethrow;
    }
  }

  /// Cierra todas las ventanas secundarias abiertas.
  /// Útil cuando la ventana principal se está cerrando.
  void terminateSecondaryWindows() {
    print('🔴 Cerrando todas las ventanas secundarias...');
    for (var process in _spawnedProcesses) {
      process.kill();
    }
    _spawnedProcesses.clear();
  }
}
