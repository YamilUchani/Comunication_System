import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/verify_email_screen.dart';
import 'screens/home_screen.dart';
import 'screens/complete_profile_screen.dart';
import 'screens/channel_input_screen.dart';
import 'dart:async';

final navigatorKey = GlobalKey<NavigatorState>();
bool _isAuthInProgress = false;
ServerSocket? _serverSocket;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final url = dotenv.env['SUPABASE_URL'];
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (url == null || anonKey == null) {
    print('❌ Error: Missing environment variables');
    return;
  }

  await Supabase.initialize(url: url, anonKey: anonKey);

  // Manejo de instancia única para Windows
  if (Platform.isWindows) {
    try {
      _serverSocket = await ServerSocket.bind('localhost', 12345);
      _serverSocket?.listen(
        (Socket client) {
          client.listen(
            (data) async {
              await _handleDeepLink(data);
            },
            onDone: () => client.close(),
            onError: (e) => print('Socket error: $e'),
          );
        },
        onError: (e) => print('ServerSocket error: $e'),
      );
    } catch (e) {
      try {
        final socket = await Socket.connect('localhost', 12345);
        if (args.isNotEmpty) {
          socket.write(args.first);
          await socket.flush();
          await socket.close();
          exit(0);
        } else {
          socket.close();
        }
      } catch (e) {
        print('Error connecting to existing instance: $e');
      }
    }
  }

  if (args.isNotEmpty) {
    await _handleDeepLink(args.first);
  }

  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    if (data.event == AuthChangeEvent.signedIn) {
      print('Auth state changed: signedIn');
      _isAuthInProgress = false;

      final next = await _nextRoute();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigatorKey.currentState?.mounted ?? false) {
          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            next,
            (route) => false,
          );
        }
      });
    }
  });

  runApp(const MyApp());
}

Future<String> _nextRoute() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return '/login';

  final profile = await Supabase.instance.client
      .from('profiles')
      .select('full_name, age')
      .eq('user_id', user.id)
      .maybeSingle();

  if (profile == null ||
      profile['full_name'] == null ||
      profile['full_name'].toString().isEmpty ||
      profile['age'] == null) {
    return '/complete-profile';
  }
  return '/home';
}

Future<void> _handleDeepLink(dynamic linkData) async {
  String link;

  if (linkData is List<int>) {
    link = String.fromCharCodes(linkData);
  } else if (linkData is String && linkData.startsWith('[')) {
    final cleaned = linkData.replaceAll(RegExp(r'[\[\]\s]'), '');
    link = cleaned.split(',').map((e) => String.fromCharCode(int.parse(e))).join();
  } else {
    link = linkData.toString().trim();
  }

  print("🔹 Link decodificado: $link");

  if (_isAuthInProgress) return;

  final uri = Uri.tryParse(link);
  if (uri == null) {
    print("❌ Error: enlace no válido");
    return;
  }

  final hostValid = uri.host == 'auth-callback';
  final pathValid = uri.path == '/' || uri.path.isEmpty;

  if (uri.scheme != 'stemforall' || !hostValid || !pathValid) {
    print("⚠️ Enlace no reconocido: ${uri.toString()}");
    if (navigatorKey.currentState?.mounted ?? false) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text('Enlace no reconocido: $link'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    return;
  }

  _isAuthInProgress = true;

  final authCode = uri.queryParameters['auth'] ?? uri.queryParameters['code'];
  final error = uri.queryParameters['error'];

  if (error != null) {
    _isAuthInProgress = false;
    print("❌ Error de autenticación recibido desde el enlace: $error");
    if (navigatorKey.currentState?.mounted ?? false) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text('Error de autenticación: $error'),
          backgroundColor: Colors.red,
        ),
      );
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    }
    return;
  }

  if (authCode == null || authCode.isEmpty) {
    _isAuthInProgress = false;
    print("⚠️ No se encontró authorization code en el enlace");
    if (navigatorKey.currentState?.mounted ?? false) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text('No se encontró authorization code en el enlace.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return;
  }

  print("🔑 Authorization code recibido: $authCode");

  try {
    final response = await Supabase.instance.client.auth.exchangeCodeForSession(authCode);

  final session = response.session;
  if (session != null) {
    print("✅ Sesión iniciada correctamente: ${session.user.email}");
    print("Access Token: ${session.accessToken}");
    print("Refresh Token: ${session.refreshToken}");

    if (navigatorKey.currentState?.mounted ?? false) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        const SnackBar(
          content: Text('Sesión iniciada correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      final next = await _nextRoute();
      navigatorKey.currentState?.pushNamedAndRemoveUntil(next, (route) => false);
    }
  } else {
    throw Exception('No se obtuvo sesión válida');
  }
  } catch (e) {
    print("❌ Error al intercambiar el authorization code: $e");
    if (navigatorKey.currentState?.mounted ?? false) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar sesión: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    _isAuthInProgress = false;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Función para obtener el nombre de usuario desde Supabase
  Future<String?> _getUserName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('user_id', user.id)
          .maybeSingle();

      return profile?['full_name'] as String?;
    } catch (e) {
      print('Error obteniendo nombre de usuario: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _nextRoute(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
              home: Scaffold(body: Center(child: CircularProgressIndicator())));
        }

        return MaterialApp(
          navigatorKey: navigatorKey,
          initialRoute: snapshot.data!,
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/login':
                return MaterialPageRoute(builder: (_) => const LoginScreen());
              case '/register':
                return MaterialPageRoute(builder: (_) => const RegisterScreen());
              case '/verify_email':
                final email = settings.arguments as String? ?? '';
                return MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: email));
              case '/home':
                return MaterialPageRoute(builder: (_) => const HomeScreen());
              case '/complete-profile':
                return MaterialPageRoute(builder: (_) => const CompleteProfileScreen());
              case '/video-call':
                // Obtener el nombre de usuario para pasarlo a ChannelInputScreen
                return MaterialPageRoute(
                  builder: (_) => FutureBuilder<String?>(
                    future: _getUserName(),
                    builder: (context, userNameSnapshot) {
                      if (userNameSnapshot.connectionState == ConnectionState.waiting) {
                        return const Scaffold(body: Center(child: CircularProgressIndicator()));
                      }
                      
                      final userName = userNameSnapshot.data ?? 'Usuario';
                      return ChannelInputScreen(userName: userName);
                    },
                  ),
                );
              default:
                return MaterialPageRoute(builder: (_) => const LoginScreen());
            }
          },
        );
      },
    );
  }
}