import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/verify_email_screen.dart';
import 'screens/home_screen.dart';
import 'screens/complete_profile_screen.dart';
import 'screens/channel_input_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/teacher_dashboard.dart';
import 'screens/student_dashboard.dart';
import 'screens/student_waiting_room_screen.dart';
import 'screens/waiting_for_assignment_screen.dart';
import 'package:window_manager/window_manager.dart';
import 'services/windows_service.dart';
import 'services/window_service.dart';
import 'services/deep_link_service.dart';
import 'video_call/video_call_screen.dart';
import 'video_call/student_video_call_screen.dart';
import 'screens/pdf_viewer_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();
bool _isAuthInProgress = false;
bool isSecondaryWindow = false; // 🪟 Indica si es una ventana secundaria (videollamada/sala espera)

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  print('DEBUG: Recibidos args: $args');

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    print('⚠️ Warning: .env file not found. Make sure to create it.');
  }

  // --- INICIALIZAR SUPABASE PARA AMBAS VENTANAS ---
  final url = dotenv.env['SUPABASE_URL'];
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (url == null || anonKey == null) {
    print('❌ Error: Missing environment variables SUPABASE_URL or SUPABASE_ANON_KEY');
    return;
  }

  await Supabase.initialize(
    url: url,
    anonKey: anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  // --- LÓGICA DE VENTANAS SECUNDARIAS ---
  if (args.contains('--secondary')) {
    isSecondaryWindow = true; // 🪟 Marcar como ventana secundaria
    print('🧩 [CHILD PROCESS] Detectado modo secundario. Supabase inicializado ✅');
    
    final mode = _getArgValue(args, 'mode') ?? 'video-call';
    final channel = _getArgValue(args, 'channel');
    final token = _getArgValue(args, 'token');
    final userName = _getArgValue(args, 'user') ?? 'Usuario';
    final userRole = _getArgValue(args, 'userRole') ?? 'teacher'; // 'student', 'teacher', 'admin'
    final uidStr = _getArgValue(args, 'uid');
    final uid = uidStr != null ? int.tryParse(uidStr) : null;
    final meetingId = _getArgValue(args, 'meetingId');
    final authToken = _getArgValue(args, 'authToken');
    final meetingTitle = _getArgValue(args, 'meetingTitle');
    final windowWidthStr = _getArgValue(args, 'windowWidth');
    final windowHeightStr = _getArgValue(args, 'windowHeight');
    final windowWidth = windowWidthStr != null ? int.tryParse(windowWidthStr) : null;
    final windowHeight = windowHeightStr != null ? int.tryParse(windowHeightStr) : null;

    final appId = dotenv.env['AGORA_APP_ID'] ?? '';
    print('   - Modo: $mode');
    print('   - Agora App ID cargado: ${appId.isNotEmpty}');

    if (mode == 'pdf-viewer') {
      final pdfUrl = _getArgValue(args, 'pdfUrl');
      final pdfTitle = _getArgValue(args, 'pdfTitle') ?? 'Visor PDF';

      if (pdfUrl != null) {
        if (Platform.isWindows) {
          await windowManager.ensureInitialized();
          await windowManager.setSize(const Size(850, 520)); // igual que videollamada del estudiante
          await windowManager.center();
        }

        runApp(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(primarySwatch: Colors.teal),
            home: PdfViewerScreen(pdfUrl: pdfUrl, title: pdfTitle),
          ),
        );
        return;
      } else {
        print('❌ [CHILD PROCESS] Faltan argumentos para PDF Viewer (pdfUrl)');
        exit(1);
      }
    } else if (channel != null && token != null) {
      try {
        if (mode == 'waiting-room') {
          // --- MODO SALA DE ESPERA ---
          print('⏳ [CHILD PROCESS] Preparando StudentWaitingRoomScreen...');
          print('   - Canal: $channel, MeetingTitle: $meetingTitle');

          // Inicializar window manager para control de ventana
          if (Platform.isWindows) {
            await windowManager.ensureInitialized();
            // Establecer tamaño minúsculo para la sala de espera
            await windowManager.setSize(const Size(250, 200));
            await windowManager.setPosition(const Offset(20, 20));
          }

          runApp(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                primarySwatch: Colors.orange,
                scaffoldBackgroundColor: const Color(0xFF212121),
              ),
              home: Scaffold(
                backgroundColor: const Color(0xFF212121),
                body: Center(
                  child: StudentWaitingRoomScreen(
                    channelName: channel,
                    token: token,
                    userName: userName,
                    meetingTitle: meetingTitle ?? 'Reunión',
                    meetingId: meetingId,
                    authToken: authToken,
                  ),
                ),
              ),
            ),
          );
        } else {
          // --- MODO VIDEOLLAMADA (POR DEFECTO) ---
          print('🎬 [CHILD PROCESS] Preparando VideoCallScreen...');
          print('   - Canal: $channel, Rol: $userRole, UID: $uid, MeetingID: $meetingId');

          // Establecer tamaño de ventana si se proporcionó
          if (Platform.isWindows && (windowWidth != null || windowHeight != null)) {
            await windowManager.ensureInitialized();
            if (windowWidth != null && windowHeight != null) {
              await windowManager.setSize(Size(windowWidth.toDouble(), windowHeight.toDouble()));
            }
          }

          // 🎓 Si es estudiante, usar StudentVideoCallScreen (sistema diferente con auto-compartir pantalla)
          if (userRole == 'student') {
            print('🎓 [STUDENT VIDEOCALL] Iniciando sistema de videollamada para estudiante...');
            runApp(MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                primarySwatch: Colors.teal,
                scaffoldBackgroundColor: Colors.black,
              ),
              home: StudentVideoCallScreen(
                channelName: channel,
                token: token,
                userName: userName,
                uid: uid,
                meetingId: meetingId,
                authToken: authToken,
              ),
            ));
          } else {
            // 👨‍🏫 Maestro y Admin usan el VideoCallScreen original
            print('👨‍🏫 [TEACHER/ADMIN VIDEOCALL] Iniciando sistema de videollamada...');
            runApp(MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                primarySwatch: Colors.teal,
                scaffoldBackgroundColor: Colors.black,
              ),
              home: VideoCallScreen(
                channelName: channel,
                token: token,
                userName: userName,
                uid: uid,
                meetingId: meetingId,
                authToken: authToken,
              ),
            ));
          }
        }
        return;
      } catch (e, stack) {
        print('❌ [CHILD PROCESS] Error FATAL al arrancar: $e');
        print(stack);
        exit(1);
      }
    } else {
      print('❌ [CHILD PROCESS] Faltan argumentos críticos (channel/token)');
      exit(1);
    }
  }

  // --- CONFIGURACIÓN PARA VENTANA PRINCIPAL ---

  if (Platform.isWindows) {
    final isMainInstance = await WindowsService.ensureSingleInstance(args, (
      data,
    ) {
      DeepLinkService.handleDeepLink(
        data,
        navigatorKey,
        (val) => _isAuthInProgress = val,
      );
    });

    if (!isMainInstance) {
      exit(0);
    }
  }

  if (args.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.handleDeepLink(
        args.first,
        navigatorKey,
        (val) => _isAuthInProgress = val,
      );
    });
  }

  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    print('🔔 Auth event received: ${data.event}');

    if (data.event == AuthChangeEvent.signedIn ||
        data.event == AuthChangeEvent.tokenRefreshed ||
        data.event == AuthChangeEvent.initialSession) {
      print('✅ Authenticated (${data.event}). Navigating...');
      _isAuthInProgress = false;

      final next = await _nextRoute();
      print('📍 Next route: $next');

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

String? _getArgValue(List<String> args, String name) {
  final prefix = '--$name=';
  for (var arg in args) {
    if (arg.startsWith(prefix)) {
      return arg.substring(prefix.length);
    }
  }
  return null;
}

Future<String> _nextRoute() async {
  final user = Supabase.instance.client.auth.currentUser;
  print('🔍 _nextRoute: Checking user: ${user?.id}');

  if (user == null) {
    print('❌ _nextRoute: User is null, returning /login');
    return '/login';
  }

  try {
    print('🔍 _nextRoute: Fetching profile for ${user.id}...');
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('full_name, age, role, group_name')
        .eq('user_id', user.id)
        .maybeSingle();

    print('🔍 _nextRoute: Profile result: $profile');

    if (profile == null) {
      print('⚠️ _nextRoute: Profile is null, returning /complete-profile');
      return '/complete-profile';
    }

    if (profile['full_name'] == null ||
        profile['full_name'].toString().isEmpty ||
        profile['age'] == null) {
      print(
        '⚠️ _nextRoute: Profile incomplete (name/age missing), returning /complete-profile',
      );
      return '/complete-profile';
    }

    // Redirección basada en roles
    final role = profile['role'] as String?;
    print('🔍 _nextRoute: Role: $role');

    // Si es administrador, permitir acceso directo sin grupo
    if (role == 'administrator') return '/admin-dashboard';

    // Verificar si tiene grupo asignado
    final groupName = profile['group_name'];
    print('🔍 _nextRoute: Group name: $groupName');

    if (groupName == null || groupName.toString().isEmpty) {
      print(
        '⚠️ _nextRoute: No group assigned, returning /waiting-for-assignment',
      );
      return '/waiting-for-assignment';
    }

    if (role == 'teacher') return '/teacher-dashboard';
    if (role == 'student') return '/student-dashboard';

    print('⚠️ _nextRoute: Unknown role, defaulting to /student-dashboard');
    return '/student-dashboard'; // Default fallback
  } catch (e) {
    print('❌ _nextRoute: Error checking profile: $e');
    return '/login';
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    // Cuando la ventana principal se cierra, matamos a los hijos
    WindowService().terminateSecondaryWindows();
    return AppExitResponse.exit;
  }

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
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
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
                return MaterialPageRoute(
                  builder: (_) => const RegisterScreen(),
                );
              case '/verify_email':
                final email = settings.arguments as String? ?? '';
                return MaterialPageRoute(
                  builder: (_) => VerifyEmailScreen(email: email),
                );
              case '/home':
                return MaterialPageRoute(builder: (_) => const HomeScreen());
              case '/admin-dashboard':
                return MaterialPageRoute(
                  builder: (_) => const AdminDashboard(),
                );
              case '/teacher-dashboard':
                return MaterialPageRoute(
                  builder: (_) => const TeacherDashboard(),
                );
              case '/student-dashboard':
                return MaterialPageRoute(
                  builder: (_) => const StudentDashboard(),
                );
              case '/complete-profile':
                return MaterialPageRoute(
                  builder: (_) => const CompleteProfileScreen(),
                );
              case '/waiting-for-assignment':
                return MaterialPageRoute(
                  builder: (_) => const WaitingForAssignmentScreen(),
                );
              case '/video-call':
                return MaterialPageRoute(
                  builder: (_) => FutureBuilder<String?>(
                    future: _getUserName(),
                    builder: (context, userNameSnapshot) {
                      if (userNameSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
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
