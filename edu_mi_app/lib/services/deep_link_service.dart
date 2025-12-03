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

    // Intentar obtener tokens de los query parameters o del fragmento
    String? accessToken = uri.queryParameters['access_token'];
    String? refreshToken = uri.queryParameters['refresh_token'];

    // Si no están en query, buscar en fragmento (formato: #access_token=...&refresh_token=...)
    if (accessToken == null && uri.fragment.isNotEmpty) {
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      accessToken = fragmentParams['access_token'];
      refreshToken = fragmentParams['refresh_token'];
    }

    final authCode = uri.queryParameters['code'];
    final error =
        uri.queryParameters['error'] ??
        uri.queryParameters['error_description'];

    if (error != null) {
      setAuthInProgress(false);
      print("❌ Error de autenticación recibido: $error");
      _showSnackBar(navigatorKey, 'Error: $error', Colors.red);
      return;
    }

    try {
      if (accessToken != null && refreshToken != null) {
        print("🔑 Tokens recibidos directamente (Implicit Flow)");
        // En implicit flow, setSession suele requerir refresh token.
        // Si la librería lo permite, pasamos ambos o solo refresh.
        // Supabase Flutter v2 setSession toma (String refreshToken).
        await Supabase.instance.client.auth.setSession(refreshToken);
      } else if (authCode != null) {
        // Fallback a PKCE si llega un código
        print("🔑 Authorization code recibido: $authCode");
        await Supabase.instance.client.auth.exchangeCodeForSession(authCode);
      } else {
        throw Exception("No se encontraron credenciales en el enlace");
      }

      print("✅ Sesión iniciada correctamente");
      _showSnackBar(
        navigatorKey,
        'Sesión iniciada correctamente',
        Colors.green,
      );
    } catch (e) {
      print("❌ Error al iniciar sesión: $e");
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
