import 'dart:io';

class SimulatorService {
  /// Ruta de la carpeta donde se deben colocar los .exe del simulador
  /// Se busca relativo al ejecutable de la app (ej: Release/simuladores/)
  static Directory get simuladoresDir {
    final exeDir = File(Platform.resolvedExecutable).parent;
    return Directory('${exeDir.path}/simuladores');
  }

  /// Devuelve la lista de archivos .exe dentro de la carpeta simuladores/
  static List<File> listarSimuladores() {
    try {
      if (!simuladoresDir.existsSync()) return [];
      return simuladoresDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('stem_for_all.exe'))
          .toList();
    } catch (e) {
      print('❌ Error listando simuladores: $e');
      return [];
    }
  }

  /// Lanza un .exe dado su ruta completa
    static Future<void> lanzar(String exePath) async {
    try {
      print('🚀 Lanzando simulador: $exePath');
      await Process.start(
        exePath,
        [],
        workingDirectory: File(exePath).parent.path,
        mode: ProcessStartMode.detached,
      );
    } catch (e) {
      print('❌ Error al lanzar simulador: $e');
      rethrow;
    }
  }

  /// Crea la carpeta simuladores/ si no existe, para que el usuario pueda
  /// simplemente pegar el .exe ahí
  static void asegurarCarpeta() {
    try {
      if (!simuladoresDir.existsSync()) {
        simuladoresDir.createSync(recursive: true);
        print('📁 Carpeta simuladores/ creada en: ${simuladoresDir.path}');
      }
    } catch (e) {
      print('⚠️ No se pudo crear la carpeta simuladores: $e');
    }
  }

  /// Abre la carpeta simuladores/ en el Explorador de Windows
  static Future<void> abrirCarpetaEnExplorador() async {
    try {
      asegurarCarpeta();
      await Process.start('explorer.exe', [simuladoresDir.path]);
    } catch (e) {
      print('❌ Error al abrir carpeta: $e');
      rethrow;
    }
  }
}
