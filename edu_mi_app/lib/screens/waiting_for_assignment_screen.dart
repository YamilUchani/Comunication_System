import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class WaitingForAssignmentScreen extends StatefulWidget {
  const WaitingForAssignmentScreen({super.key});

  @override
  State<WaitingForAssignmentScreen> createState() =>
      _WaitingForAssignmentScreenState();
}

class _WaitingForAssignmentScreenState
    extends State<WaitingForAssignmentScreen> {
  // ✅ CAMBIO A REALTIME LISTENER (no polling cada 5 segundos)
  StreamSubscription<List<Map<String, dynamic>>>? _profileListener;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    // ✅ Limpiar listener realtime
    _profileListener?.cancel();
    super.dispose();
  }

  void _setupRealtimeListener() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        print('❌ No hay usuario activo para escuchar');
        return;
      }

      print('🎧 [WaitingScreen] Configurando escucha realtime de perfil...');

      // Usar realtime listener en lugar de polling cada 5 segundos
      // Esto es MUCHO más eficiente: 0 consultas hasta que cambie el dato
      _profileListener = Supabase.instance.client
          .from('profiles')
          .stream(primaryKey: ['user_id'])
          .eq('user_id', user.id)
          .listen(
            (List<Map<String, dynamic>> records) {
              if (!mounted) return;

              if (records.isEmpty) {
                print('⚠️ [WaitingScreen] Perfil no encontrado');
                return;
              }

              final profile = records.first;
              final groupName = profile['group_name'];
              final role = profile['role'] ?? 'student';

              print(
                '📡 [WaitingScreen] Cambio detectado - group_name: $groupName, role: $role',
              );

              // Si ya tiene grupo asignado, redirigir al dashboard correspondiente
              if (groupName != null && groupName.isNotEmpty) {
                print('✅ [WaitingScreen] Usuario asignado - redirigiendo...');
                _profileListener?.cancel();

                if (role == 'administrator') {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/admin-dashboard', (route) => false);
                } else if (role == 'teacher') {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/teacher-dashboard', (route) => false);
                } else {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/student-dashboard', (route) => false);
                }
              }
            },
            onError: (e) {
              print('❌ [WaitingScreen] Error en realtime listener: $e');
            },
          );
    } catch (e) {
      print('❌ [WaitingScreen] Error configurando listener: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade400, Colors.purple.shade400],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icono animado
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(seconds: 2),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: 0.8 + (value * 0.2),
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.hourglass_empty,
                      size: 80,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Título
                const Text(
                  '¡Bienvenido!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Mensaje principal
                const Text(
                  'Esperando asignación de grupo',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Descripción
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Un administrador te asignará a un grupo pronto.\n'
                    'Recibirás acceso automáticamente cuando esto suceda.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),

                // Indicador de carga
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Verificando...',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 60),

                // Botón de cerrar sesión
                OutlinedButton.icon(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/login', (route) => false);
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
