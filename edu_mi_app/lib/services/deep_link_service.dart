import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeepLinkService {
  static Future<void> handleDeepLink(
    dynamic linkData,
    GlobalKey<NavigatorState> navigatorKey,
    Function(bool) setAuthInProgress,
  ) async {
    String link;

    if (linkData is List<int>) {
      link = String.fromCharCodes(linkData);
    } else if (linkData is String && linkData.startsWith('[')) {
      final cleaned = linkData.replaceAll(RegExp(r'[\[\]\s]'), '');
      link = cleaned
          .split(',')
          .map((e) => String.fromCharCode(int.parse(e)))
          .join();
    } else {
      link = linkData.toString().trim();
    }

    print("🔹 Link decodificado: $link");

    final uri = Uri.tryParse(link);
    if (uri == null) {
      print("❌ Error: enlace no válido");
      return;
    }

    final hostValid = uri.host == 'auth-callback';
    final pathValid = uri.path == '/' || uri.path.isEmpty;

    if (uri.scheme != 'stemforall' || !hostValid || !pathValid) {
      print("⚠️ Enlace no reconocido: ${uri.toString()}");
      _showSnackBar(navigatorKey, 'Enlace no reconocido: $link', Colors.orange);
      return;
    }

    setAuthInProgress(true);

    final authCode = uri.queryParameters['auth'] ?? uri.queryParameters['code'];
    final error = uri.queryParameters['error'];

    if (error != null) {
      setAuthInProgress(false);
      print("❌ Error de autenticación recibido desde el enlace: $error");
      _showSnackBar(navigatorKey, 'Error de autenticación: $error', Colors.red);
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
      return;
    }

    if (authCode == null || authCode.isEmpty) {
      setAuthInProgress(false);
      print("⚠️ No se encontró authorization code en el enlace");
      _showSnackBar(
        navigatorKey,
        'No se encontró authorization code en el enlace.',
        Colors.orange,
      );
      return;
    }

    print("🔑 Authorization code recibido: $authCode");

    try {
      final response = await Supabase.instance.client.auth
          .exchangeCodeForSession(authCode);
      final session = response.session;

      print("✅ Sesión iniciada correctamente: ${session.user.email}");
      _showSnackBar(
        navigatorKey,
        'Sesión iniciada correctamente',
        Colors.green,
      );

      // La navegación se manejará por el listener de auth state en main
    } catch (e) {
      print("❌ Error al intercambiar el authorization code: $e");
      _showSnackBar(navigatorKey, 'Error al iniciar sesión: $e', Colors.red);
    } finally {
      setAuthInProgress(false);
    }
  }

  static void _showSnackBar(
    GlobalKey<NavigatorState> navigatorKey,
    String message,
    Color color,
  ) {
    if (navigatorKey.currentState?.mounted ?? false) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
