import 'dart:io';

class WindowsService {
  static const int _port = 12345;

  /// Intenta iniciar un servidor socket para asegurar una instancia única.
  /// Retorna `true` si esta es la instancia principal.
  /// Retorna `false` si ya existe otra instancia (y envía los argumentos a ella).
  static Future<bool> ensureSingleInstance(List<String> args, Function(String) onDataReceived) async {
    // Si contiene el flag '--secondary', permitimos que se abra otra instancia
    if (args.contains('--secondary')) {
      return true;
    }

    try {
      final serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, _port);
      serverSocket.listen(
        (Socket client) {
          client.listen(
            (data) {
              final message = String.fromCharCodes(data);
              onDataReceived(message);
            },
            onDone: () => client.close(),
            onError: (e) => print('Socket error: $e'),
          );
        },
        onError: (e) => print('ServerSocket error: $e'),
      );
      return true;
    } catch (e) {
      // Si falla el bind, probablemente ya existe una instancia.
      await _sendArgsToExistingInstance(args);
      return false;
    }
  }

  static Future<void> _sendArgsToExistingInstance(List<String> args) async {
    try {
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, _port);
      if (args.isNotEmpty) {
        socket.write(args.first);
        await socket.flush();
      }
      await socket.close();
    } catch (e) {
      print('Error connecting to existing instance: $e');
    }
  }
}
