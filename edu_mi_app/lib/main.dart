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
import 'services/windows_service.dart';
import 'services/deep_link_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();
bool _isAuthInProgress = false;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    print('⚠️ Warning: .env file not found. Make sure to create it.');
  }

  final url = dotenv.env['SUPABASE_URL'];
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (url == null || anonKey == null) {
    print('❌ Error: Missing environment variables SUPABASE_URL or SUPABASE_ANON_KEY');
    // Podríamos mostrar un error visual si fuera necesario, pero por ahora logueamos y retornamos.
    return;
  }

  await Supabase.initialize(url: url, anonKey: anonKey);

  // Manejo de instancia única para Windows
  if (Platform.isWindows) {
    final isMainInstance = await WindowsService.ensureSingleInstance(
      args,
      (data) {
        // Callback cuando se reciben datos de otra instancia
        DeepLinkService.handleDeepLink(data, navigatorKey, (val) => _isAuthInProgress = val);
      },
    );

    if (!isMainInstance) {
      exit(0);
    }
  }

  // Manejo de deep link inicial si existe
  if (args.isNotEmpty) {
    // Pequeño delay para asegurar que la UI esté lista si es necesario, 
    // aunque handleDeepLink usa navigatorKey que puede no estar listo aún.
    // En este caso, como es el inicio, el listener de auth state probablemente maneje la sesión si el token es válido.
    // Pero si es un link de auth, necesitamos procesarlo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
       DeepLinkService.handleDeepLink(args.first, navigatorKey, (val) => _isAuthInProgress = val);
    });
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

  try {
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
  } catch (e) {
    print('Error checking profile: $e');
    return '/login'; // Fallback en caso de error
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
              home: Scaffold(body: Center(child: CircularProgressIndicator())));
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Edu Mi App',
          navigatorKey: navigatorKey,
          initialRoute: snapshot.data ?? '/login',
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