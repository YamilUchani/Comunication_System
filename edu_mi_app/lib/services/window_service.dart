import 'dart:io';
import 'dart:convert';

class WindowService {
  static final WindowService _instance = WindowService._internal();
  factory WindowService() => _instance;
  WindowService._internal();

  final List<Process> _spawnedProcesses = [];
  
  /// 🔍 Ruta de archivo compartido para registrar PIDs secundarios
  /// Todos los procesos (main + secondary) escriben aquí sus PIDs
  static String get _pidRegistryFile {
    final tempDir = Directory.systemTemp;
    return '${tempDir.path}${Platform.pathSeparator}edu_mi_app_pids.json';
  }
  
  /// 🎨 Trackea las pizarras abiertas por meetingId
  /// Previene múltiples pizarras para la misma reunión
  final Map<String, Process> _openWhiteboards = {};

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
    bool isPrivateClass = false,
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
      if (isPrivateClass) '--isPrivateClass=true',
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
      print('   ✅ Ventana iniciada con PID: ${process.pid}');
      print('   📊 Total de procesos rastreados ahora: ${_spawnedProcesses.length}');
      print('   📋 PIDs rastreados: ${_spawnedProcesses.map((p) => p.pid).toList()}');

      // Limpiar de la lista si el proceso termina solo
      process.exitCode.then((_) {
        _spawnedProcesses.remove(process);
        print('   🧹 Proceso PID ${process.pid} terminó solo. Removido del tracking.');
      });
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
    bool isPrivateClass = false,
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
      if (isPrivateClass) '--isPrivateClass=true',
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
      print('   ✅ Ventana iniciada con PID: ${process.pid}');
      print('   📊 Total de procesos rastreados ahora: ${_spawnedProcesses.length}');
      print('   📋 PIDs rastreados: ${_spawnedProcesses.map((p) => p.pid).toList()}');

      // Limpiar de la lista si el proceso termina solo
      process.exitCode.then((_) {
        _spawnedProcesses.remove(process);
        print('   🧹 Proceso PID ${process.pid} terminó solo. Removido del tracking.');
      });
    } catch (e) {
      print('   ❌ Error al iniciar ventana secundaria: $e');
      rethrow;
    }
  }

  /// Cierra todas las ventanas secundarias abiertas.
  /// Útil cuando la ventana principal se está cerrando.
  /// 🔧 AHORA: Lee del archivo de registro compartido en lugar de solo usar _spawnedProcesses
  Future<void> terminateSecondaryWindows() async {
    print('🔴 Cerrando todas las ventanas secundarias...');
    
    // Primero, intentar leer PIDs del registry compartido
    final registryPids = await _readPidRegistry();
    print('   📋 PIDs del registry: $registryPids');
    
    // Combinar con los que conocemos localmente
    final allPids = <int>{
      ..._spawnedProcesses.map((p) => p.pid),
      ...registryPids,
    };
    
    print('   📊 Total de PIDs a terminar: ${allPids.length}');
    print('   📋 PIDs combinados: ${allPids.toList()}');
    
    if (allPids.isEmpty) {
      print('   ⚠️  No hay procesos secundarios para cerrar');
      return;
    }
    
    // Terminar todos los PIDs
    for (int pid in allPids) {
      try {
        print('   🔪 Terminando PID $pid...');
        if (Platform.isWindows) {
          // En Windows, process.kill() (SIGTERM) a veces es ignorado si la app está bloqueada
          // por un thread en C++ (ej. Agora o FFI). Usamos taskkill /F /T brutalmente.
          // 🔧 CRITICAL: await para esperar a que se complete
          final result = await Process.run('taskkill', ['/F', '/T', '/PID', pid.toString()]);
          print('   ✅ taskkill resultado: exitCode=${result.exitCode}');
          if (result.stdout.isNotEmpty) print('   📤 stdout: ${result.stdout}');
          if (result.stderr.isNotEmpty) print('   📤 stderr: ${result.stderr}');
          print('   ✅ Proceso PID $pid terminado (Windows)');
        } else {
          // En Linux/Mac:  usar kill -9
          await Process.run('kill', ['-9', pid.toString()]);
          print('   ✅ Proceso PID $pid terminado (Linux/Mac)');
        }
      } catch (e) {
        print('   ⚠️  Error terminando PID $pid: $e');
      }
    }
    
    print('   🧹 Limpiando lista local de procesos...');
    _spawnedProcesses.clear();
    
    print('   🗑️ Limpiando registry de PIDs...');
    await _clearPidRegistry();
    
    print('✅ Todas las ventanas secundarias cerraron correctamente');
    
    // Esperar un bit para asegurar que los procesos realmente terminen
    print('   ⏳ Esperando 500ms para asegurar terminación...');
    await Future.delayed(const Duration(milliseconds: 500));
    print('   ✅ Espera completada');
  }

  /// Abre una nueva ventana para visor de PDF.
  /// 
  /// [pdfUrl]: URL del PDF a mostrar.
  /// [title]: Título del modelo/PDF.
  Future<void> openPdfViewerWindow({
    required String pdfUrl,
    required String title,
  }) async {
    final String executablePath = Platform.resolvedExecutable;
    
    // Argumentos para la nueva instancia
    final List<String> args = [
      '--secondary',
      '--mode=pdf-viewer',
      '--pdfUrl=$pdfUrl',
      '--pdfTitle=$title',
    ];

    print('🚀 Iniciando ventana secundaria de visor PDF...');
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
      print('   ❌ Error al iniciar ventana de visor PDF: $e');
      rethrow;
    }
  }

  /// Abre la pizarra a pantalla completa como overlay
  /// Solo permite UNA pizarra por meetingId - ignora clicks duplicados
  Future<void> openWhiteboardWindow({
    required String meetingId,
    required bool isTeacher,
  }) async {
    // 🔒 Validación: Si ya existe pizarra abierta para este meetingId, no hacer nada
    if (_openWhiteboards.containsKey(meetingId)) {
      print('⚠️  Pizarra para meetingId=$meetingId ya está abierta. Ignorando click adicional.');
      return;
    }

    final String executablePath = Platform.resolvedExecutable;
    
    final List<String> args = [
      '--secondary',
      '--mode=whiteboard',
      '--meetingId=$meetingId',
      '--isTeacher=$isTeacher',
    ];

    print('🚀 Iniciando ventana secundaria de Pizarra...');
    print('   CMD: $executablePath ${args.join(' ')}');

    try {
      final process = await Process.start(executablePath, args);
      
      process.stdout.transform(utf8.decoder).listen((data) {
        stdout.write('[CHILD-OUT] $data');
      });
      process.stderr.transform(utf8.decoder).listen((data) {
        stderr.write('[CHILD-ERR] $data');
      });

      _spawnedProcesses.add(process);
      _openWhiteboards[meetingId] = process;
      
      // Cuando se cierra la pizarra, limpiar del registry
      process.exitCode.then((_) {
        _spawnedProcesses.remove(process);
        _openWhiteboards.remove(meetingId);
        print('✅ Pizarra meetingId=$meetingId cerrada. Registry limpiado.');
      });
      
      print('   ✅ Ventana de Pizarra iniciada con PID: ${process.pid}');
    } catch (e) {
      print('   ❌ Error al iniciar ventana de Pizarra: $e');
      rethrow;
    }
  }

  /// ✅ Verifica si hay una pizarra abierta para un meetingId específico
  bool isWhiteboardOpen(String meetingId) {
    return _openWhiteboards.containsKey(meetingId);
  }

  /// Cierra la pizarra abierta para un meetingId específico
  Future<void> closeWhiteboardWindow(String meetingId) async {
    final process = _openWhiteboards[meetingId];
    if (process != null) {
      print('🔴 Cerrando pizarra meetingId=$meetingId...');
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/T', '/PID', process.pid.toString()]);
      } else {
        process.kill(ProcessSignal.sigkill);
      }
      _openWhiteboards.remove(meetingId);
      _spawnedProcesses.remove(process);
      print('   ✅ Pizarra cerrada');
    }
  }

  /// 📝 REGISTRY: Lee todos los PIDs secundarios activos del archivo compartido
  Future<List<int>> _readPidRegistry() async {
    try {
      final file = File(_pidRegistryFile);
      if (!file.existsSync()) {
        print('📄 Archivo de PIDs no existe aún');
        return [];
      }
      
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      
      // Intentar leer nuevo formato (array de objects)
      final processesList = json['processes'] as List<dynamic>?;
      if (processesList != null && processesList.isNotEmpty) {
        final pidList = processesList
            .map((p) => (p as Map<String, dynamic>?)?['pid'] as int?)
            .whereType<int>()
            .toList();
        print('📖 Registry leído (formato nuevo): $pidList');
        
        // Mostrar detalles
        for (var p in processesList) {
          if (p is Map<String, dynamic>) {
            print('    📋 PID ${p['pid']}: ${p['mode']} (${p['role']})');
          }
        }
        
        return pidList;
      }
      
      // Fallback: intentar leer formato antiguo (array de ints)
      final pidList = (json['pids'] as List<dynamic>?)?.cast<int>() ?? [];
      print('📖 Registry leído (formato antiguo): $pidList');
      return pidList;
    } catch (e) {
      print('⚠️ Error leyendo registry de PIDs: $e');
      return [];
    }
  }

  /// 📝 REGISTRY: Escribe el PID actual al archivo compartido (para secundarios)
  /// Los procesos secundarios se auto-registran cuando inician
  Future<void> _registerCurrentProcessPid() async {
    try {
      // 🔍 Nota: Esta función es llamada desde main.dart para procesos secundarios
      // No verificamos isSecondaryWindow aquí porque no es accesible en este contexto
      
      final file = File(_pidRegistryFile);
      final currentPid = pid; // dart:io provides pid variable
      
      // Leer PIDs existentes
      List<int> pids = [];
      if (file.existsSync()) {
        try {
          final content = await file.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          pids = (json['pids'] as List<dynamic>?)?.cast<int>() ?? [];
        } catch (e) {
          print('⚠️ Error leyendo registry anterior: $e');
        }
      }
      
      // Agregar SI NO ESTÁ DUPLICADO
      if (!pids.contains(currentPid)) {
        pids.add(currentPid);
        print('✅ PID secundario $currentPid registrado en file');
      }
      
      // Escribir de vuelta
      final json = jsonEncode({'pids': pids, 'timestamp': DateTime.now().toIso8601String()});
      await file.writeAsString(json);
    } catch (e) {
      print('⚠️ Error registrando PID: $e');
    }
  }

  /// 📝 REGISTRY: Limpia el archivo de registry (al cerrar main)
  Future<void> _clearPidRegistry() async {
    try {
      final file = File(_pidRegistryFile);
      if (file.existsSync()) {
        await file.delete();
        print('🗑️ Registry de PIDs limpiado');
      }
    } catch (e) {
      print('⚠️ Error limpiando registry: $e');
    }
  }
}
