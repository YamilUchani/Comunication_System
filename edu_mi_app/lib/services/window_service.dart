import 'dart:io';
import 'dart:convert';

class WindowService {
  static final WindowService _instance = WindowService._internal();
  factory WindowService() => _instance;
  WindowService._internal();

  final List<Process> _spawnedProcesses = [];

  /// Abre una nueva ventana de videollamada para el maestro.
  /// 
  /// [channelName]: Nombre del canal de Agora.
  /// [token]: Token de acceso Agora.
  /// [userName]: Nombre del maestro.
  /// [meetingId]: ID de la reunión para heartbeat.
  /// [authToken]: Token de autenticación de Supabase.
  Future<void> openVideoCallWindow({
    required String channelName,
    required String token,
    required String userName,
    String? meetingId,
    String? authToken,
    int uid = 0,
  }) async {
    final String executablePath = Platform.resolvedExecutable;
    
    // Argumentos para la nueva instancia
    final List<String> args = [
      '--secondary',
      '--mode=video-call',
      '--channel=$channelName',
      '--token=$token',
      '--user=$userName',
      '--uid=$uid',
      if (meetingId != null) '--meetingId=$meetingId',
      if (authToken != null) '--authToken=$authToken',
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
